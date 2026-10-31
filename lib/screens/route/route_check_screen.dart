import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../../services/place_search_service.dart';
import '../../services/route_service.dart';
import '../../services/saved_places_service.dart';
import '../../services/voice_guard_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/safeher_map.dart';

enum _Mode { walk, car, transit }

class RouteCheckScreen extends StatefulWidget {
  const RouteCheckScreen({super.key});

  @override
  State<RouteCheckScreen> createState() => _RouteCheckScreenState();
}

class _RouteCheckScreenState extends State<RouteCheckScreen> {
  final _routeService = RouteService();
  final _placeSearch = PlaceSearchService();
  final _savedPlaces = SavedPlacesService();
  final _destinationController = TextEditingController();
  final _focusNode = FocusNode();
  final _mapController = MapController();
  final _speech = stt.SpeechToText();

  StreamSubscription<Map<String, SavedPlace>>? _savedSub;
  Timer? _debounce;
  int _searchSeq = 0;

  RoutePoint? _currentLocation;
  RoutePoint? _selectedDestination;
  RouteCheckResult? _result;
  Map<String, SavedPlace> _saved = {};
  List<PlaceResult> _suggestions = [];
  _Mode _mode = _Mode.walk;

  bool _isLoadingLocation = true;
  bool _isChecking = false;
  bool _isSearching = false;
  bool _showList = false;
  String? _searchError;
  String? _error;

  // 'home' or 'work' while the user is choosing that shortcut.
  String? _settingShortcut;

  bool _speechReady = false;
  bool _isListening = false;
  bool _guardPausedByUs = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _savedSub = _savedPlaces.watchPlaces().listen((places) {
      if (mounted) setState(() => _saved = places);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _savedSub?.cancel();
    _speech.cancel();
    _resumeGuard();
    _destinationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _error = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are turned off.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is needed for route checking.');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentLocation = RoutePoint(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoadingLocation = false;
      });
    }
  }

  void _recenter() {
    final loc = _currentLocation;
    if (loc == null) return;
    try {
      _mapController.move(LatLng(loc.lat, loc.lng), 15);
    } catch (_) {}
  }

  void _fitRoute() {
    final loc = _currentLocation;
    final dest = _selectedDestination;
    if (loc == null || dest == null) return;
    try {
      final points = <LatLng>[
        LatLng(loc.lat, loc.lng),
        LatLng(dest.lat, dest.lng),
        ...?_result?.path.map((p) => LatLng(p.lat, p.lng)),
      ];
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(40, 160, 40, 220),
        ),
      );
    } catch (_) {}
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onQueryChanged(String text) {
    _selectedDestination = null;
    _debounce?.cancel();
    if (text.trim().length < 2) {
      _searchSeq++;
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _searchError = null;
        _showList = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _showList = true;
    });
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _runSearch(text),
    );
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq;
    try {
      final results = await _placeSearch.search(
        query,
        nearLat: _currentLocation?.lat,
        nearLng: _currentLocation?.lng,
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
        _searchError = null;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _searchError =
            'Could not load suggestions. Check your internet connection.';
      });
    }
  }

  Future<void> _selectPlace(PlaceResult place) async {
    _debounce?.cancel();
    _searchSeq++;
    FocusScope.of(context).unfocus();

    if (_settingShortcut != null) {
      await _saveShortcut(_settingShortcut!, place);
      return;
    }

    _destinationController.text = place.title;
    setState(() {
      _suggestions = [];
      _isSearching = false;
      _showList = false;
      _selectedDestination = RoutePoint(place.lat, place.lng);
    });
    await _checkRoute();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchSeq++;
    _destinationController.clear();
    setState(() {
      _selectedDestination = null;
      _suggestions = [];
      _isSearching = false;
      _showList = false;
      _searchError = null;
      _result = null;
      _error = null;
    });
  }

  Future<RoutePoint?> _resolveTyped(String text) async {
    try {
      final r = await _placeSearch.search(
        text,
        nearLat: _currentLocation?.lat,
        nearLng: _currentLocation?.lng,
      );
      if (r.isNotEmpty) return RoutePoint(r.first.lat, r.first.lng);
    } catch (_) {}
    return _routeService.geocodeAddress(text);
  }

  void _setMode(_Mode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _result = null;
      _error = null;
    });
    if (_selectedDestination != null) _checkRoute();
  }

  Future<void> _checkRoute() async {
    final from = _currentLocation;
    if (from == null) return;
    final text = _destinationController.text.trim();
    if (_selectedDestination == null && text.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isChecking = true;
      _showList = false;
      _error = null;
      _result = null;
    });
    try {
      final destination = _selectedDestination ?? await _resolveTyped(text);
      if (destination == null) {
        throw Exception(
          'Could not find that place. Pick one from the suggestions, or add the area or city.',
        );
      }
      if (!mounted) return;

      if (_mode == _Mode.transit) {
        // Bus and train routes are opened in Google Maps.
        setState(() => _selectedDestination = destination);
      } else {
        final result = await _routeService.checkRoute(
          from: from,
          to: destination,
          mode: _mode == _Mode.car ? TravelMode.car : TravelMode.walk,
        );
        if (!mounted) return;
        setState(() {
          _result = result;
          _selectedDestination = destination;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _onSubmitted(String _) {
    if (_suggestions.isNotEmpty && _selectedDestination == null) {
      _selectPlace(_suggestions.first);
    } else if (_settingShortcut == null) {
      _checkRoute();
    }
  }

  Future<void> _openTransit() async {
    final loc = _currentLocation;
    final dest = _selectedDestination;
    if (loc == null || dest == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${loc.lat},${loc.lng}&destination=${dest.lat},${dest.lng}&travelmode=transit',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('Could not open Google Maps.');
    }
  }

  // ── Home and Work ─────────────────────────────────────────────────────────

  String _labelFor(String key) => key == 'home' ? 'Home' : 'Work';

  void _startSettingShortcut(String key) {
    _debounce?.cancel();
    _searchSeq++;
    _destinationController.clear();
    setState(() {
      _settingShortcut = key;
      _suggestions = [];
      _showList = false;
      _selectedDestination = null;
      _result = null;
      _error = null;
    });
    _focusNode.requestFocus();
  }

  void _cancelSettingShortcut() {
    _destinationController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _settingShortcut = null;
      _suggestions = [];
      _showList = false;
    });
  }

  Future<void> _saveShortcut(String key, PlaceResult place) async {
    final label = _labelFor(key);
    try {
      await _savedPlaces.savePlace(
        SavedPlace(
          key: key,
          name: place.title,
          address: place.fullName,
          lat: place.lat,
          lng: place.lng,
        ),
      );
      _destinationController.clear();
      if (!mounted) return;
      setState(() {
        _settingShortcut = null;
        _suggestions = [];
        _showList = false;
      });
      _snack('$label saved: ${place.title}');
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        _snack(
          'Could not save $label: the database does not allow saved places yet (security rules).',
        );
      } else {
        _snack('Could not save $label. Check your connection and try again.');
      }
    }
  }

  void _onShortcutTap(String key) {
    final saved = _saved[key];
    if (saved == null) {
      _startSettingShortcut(key);
      return;
    }
    _debounce?.cancel();
    _searchSeq++;
    _destinationController.text = saved.name;
    setState(() {
      _settingShortcut = null;
      _suggestions = [];
      _showList = false;
      _selectedDestination = RoutePoint(saved.lat, saved.lng);
    });
    _checkRoute();
  }

  Future<void> _shortcutOptions(String key) async {
    final saved = _saved[key];
    if (saved == null) {
      _startSettingShortcut(key);
      return;
    }
    final label = _labelFor(key);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: Text('Change $label'),
              subtitle: Text(saved.name),
              onTap: () => Navigator.pop(ctx, 'change'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.dangerLight,
              ),
              title: Text('Remove $label'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'change') {
      _startSettingShortcut(key);
    } else if (choice == 'remove') {
      try {
        await _savedPlaces.removePlace(key);
        _snack('$label removed');
      } catch (_) {
        _snack('Could not remove $label. Try again.');
      }
    }
  }

  // ── Voice search ──────────────────────────────────────────────────────────

  void _resumeGuard() {
    if (_guardPausedByUs) {
      _guardPausedByUs = false;
      VoiceGuardService().resume();
    }
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (mounted) setState(() => _isListening = false);
      _resumeGuard();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords;
    if (words.isEmpty || !mounted) return;
    _destinationController.value = TextEditingValue(
      text: words,
      selection: TextSelection.collapsed(offset: words.length),
    );
    _onQueryChanged(words);
  }

  Future<void> _stopVoice() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
    _resumeGuard();
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _stopVoice();
      return;
    }

    // Voice Guard also uses the microphone, so pause it while we listen.
    final guard = VoiceGuardService();
    if (guard.isActive && !guard.isPaused) {
      guard.pause();
      _guardPausedByUs = true;
    }

    try {
      if (!_speechReady) {
        _speechReady = await _speech.initialize(
          onStatus: _onSpeechStatus,
          onError: (e) {
            if (mounted) setState(() => _isListening = false);
            _resumeGuard();
            _snack('Voice search problem: ${e.errorMsg}');
          },
        );
      }
      if (!_speechReady) {
        _resumeGuard();
        _snack('Voice search is unavailable. Check microphone permission.');
        return;
      }

      // Give Voice Guard a moment to let go of the microphone.
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) {
        _resumeGuard();
        return;
      }
      FocusScope.of(context).unfocus();
      setState(() => _isListening = true);

      await _speech.listen(
        onResult: _onSpeechResult,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.search,
          partialResults: true,
          cancelOnError: true,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 12),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isListening = false);
      _resumeGuard();
      _snack('Voice search could not start.');
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  Color _noteColor(int count) {
    if (count == 0) return AppColors.success;
    if (count <= 2) return AppColors.warning;
    return AppColors.dangerLight;
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  @override
  Widget build(BuildContext context) {
    final showTransit =
        _mode == _Mode.transit &&
        _selectedDestination != null &&
        !_isChecking &&
        _currentLocation != null;
    final hasCard = _result != null || showTransit;

    return Scaffold(
      appBar: AppBar(title: const Text('Route Check')),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          Positioned(top: 0, left: 0, right: 0, child: _buildSearchPanel()),
          if (_currentLocation != null)
            Positioned(
              right: AppSpacing.md,
              bottom: hasCard ? 210 : AppSpacing.lg,
              child: FloatingActionButton.small(
                heroTag: 'route_recenter',
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primaryLight,
                onPressed: _recenter,
                child: const Icon(Icons.my_location),
              ),
            ),
          if (_result != null)
            Positioned(
              bottom: 30,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: _buildResultCard(),
            ),
          if (showTransit)
            Positioned(
              bottom: 30,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: _buildTransitCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_isLoadingLocation) {
      return const Center(child: CircularProgressIndicator());
    }
    final loc = _currentLocation;
    if (loc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            180,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _error ?? 'Location unavailable',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _loadCurrentLocation,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final result = _result;
    final dest = _selectedDestination;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(loc.lat, loc.lng),
        initialZoom: 14,
        onTap: (_, _) {
          FocusScope.of(context).unfocus();
          if (_showList) setState(() => _showList = false);
        },
      ),
      children: [
        const SafeHerTileLayer(),
        if (result != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: result.path.map((p) => LatLng(p.lat, p.lng)).toList(),
                strokeWidth: 6,
                color: AppColors.primaryLight,
                borderStrokeWidth: 2,
                borderColor: AppColors.background,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(loc.lat, loc.lng),
              width: 48,
              height: 48,
              child: const MyLocationDot(),
            ),
            if (dest != null)
              Marker(
                point: LatLng(dest.lat, dest.lng),
                width: 48,
                height: 52,
                alignment: Alignment.topCenter,
                child: const DestinationPin(),
              ),
          ],
        ),
        const SafeHerAttribution(),
      ],
    );
  }

  Widget _modeChip(_Mode mode, String label, IconData icon) {
    final selected = _mode == mode;
    return ChoiceChip(
      showCheckmark: false,
      elevation: 3,
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => _setMode(mode),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSearchPanel() {
    final hasText = _destinationController.text.isNotEmpty;
    final settingLabel = _settingShortcut == null
        ? null
        : _labelFor(_settingShortcut!);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.only(left: 18, right: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      settingLabel == null ? Icons.search : Icons.edit_location,
                      size: 22,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _destinationController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.search,
                        onChanged: _onQueryChanged,
                        onSubmitted: _onSubmitted,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          fillColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: _isListening
                              ? 'Listening... say a place'
                              : (settingLabel == null
                                    ? 'Where to?'
                                    : 'Search your $settingLabel address'),
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    if (_isSearching || _isChecking)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    if (hasText)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 20),
                        color: AppColors.textSecondary,
                        tooltip: 'Clear',
                        onPressed: _clearSearch,
                      ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Search by voice',
                      child: Material(
                        color: _isListening
                            ? AppColors.danger
                            : AppColors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _toggleVoice,
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (settingLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pick a place from the list to save it as $settingLabel.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _cancelSettingShortcut,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _modeChip(_Mode.walk, 'Walk', Icons.directions_walk),
                      const SizedBox(width: 8),
                      _modeChip(_Mode.car, 'Car', Icons.directions_car),
                      const SizedBox(width: 8),
                      _modeChip(
                        _Mode.transit,
                        'Bus / Train',
                        Icons.directions_transit,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ShortcutChip(
                        icon: Icons.home_outlined,
                        label: 'Home',
                        sub: _saved['home']?.name,
                        onTap: () => _onShortcutTap('home'),
                        onLongPress: () => _shortcutOptions('home'),
                      ),
                      const SizedBox(width: 12),
                      _ShortcutChip(
                        icon: Icons.work_outline,
                        label: 'Work',
                        sub: _saved['work']?.name,
                        onTap: () => _onShortcutTap('work'),
                        onLongPress: () => _shortcutOptions('work'),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.dangerLight,
                      ),
                    ),
                  ),
                ),
              if (_showList) ...[
                const SizedBox(height: 12),
                _buildSuggestions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    Widget message(String text, {Color color = AppColors.textSecondary}) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Text(text, style: TextStyle(fontSize: 13, color: color)),
      );
    }

    Widget body;
    if (_searchError != null) {
      body = message(_searchError!, color: AppColors.dangerLight);
    } else if (_suggestions.isEmpty) {
      body = _isSearching
          ? message('Searching...')
          : message('No places found. Try a different name or add the city.');
    } else {
      body = ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 64, color: AppColors.border),
        itemBuilder: (context, index) {
          final p = _suggestions[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            leading: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceElevated,
              child: Icon(
                Icons.place_outlined,
                size: 18,
                color: AppColors.primaryLight,
              ),
            ),
            title: Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: p.subtitle.isEmpty
                ? null
                : Text(
                    p.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
            onTap: () => _selectPlace(p),
          );
        },
      );
    }

    return Material(
      elevation: 8,
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: body,
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _result!;
    final color = result.incidentDataAvailable
        ? _noteColor(result.nearbyReportCount)
        : AppColors.textSecondary;
    final isCar = result.mode == TravelMode.car;
    final tooFarToWalk = !isCar && result.distanceMeters > 20000;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCar ? Icons.directions_car : Icons.directions_walk,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                isCar
                    ? '${_formatDuration(result.durationSeconds)} by car'
                    : '${_formatDuration(result.durationSeconds)} walk',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(result.distanceMeters / 1000).toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.incidentDataAvailable
                      ? '${result.nearbyReportCount} report${result.nearbyReportCount == 1 ? '' : 's'} nearby'
                      : 'Incident data unavailable',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.safetyNote,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.35,
            ),
          ),
          if (tooFarToWalk) ...[
            const SizedBox(height: 6),
            const Text(
              'This is a long way to walk. Try Car or Bus / Train.',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            isCar
                ? 'Estimate without live traffic. Safety information only, never a guarantee a route is safe.'
                : 'Estimate at a 5 km/h walking pace. Safety information only, never a guarantee a route is safe.',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.directions_transit,
                size: 18,
                color: AppColors.primaryLight,
              ),
              SizedBox(width: 8),
              Text(
                'Bus and train',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'SafeHer cannot plan bus and train trips itself. Google Maps shows live public-transport options, times and fares for this trip.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openTransit,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open in Google Maps'),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'The incident check works only for walking and car routes.',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isSet = sub != null && sub!.isNotEmpty;
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSet
              ? AppColors.primary.withValues(alpha: 0.6)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSet ? AppColors.primaryLight : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      isSet ? sub! : 'Tap to set',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
