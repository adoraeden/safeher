import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/emergency_contact.dart';
import '../../services/contacts_service.dart';
import '../../services/location_share_service.dart';
import '../../services/sms_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class LiveLocationScreen extends StatefulWidget {
  final LocationShareService? service;
  final Stream<List<EmergencyContact>>? contactsStream;

  const LiveLocationScreen({super.key, this.service, this.contactsStream});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  late final LocationShareService _service =
      widget.service ?? LocationShareService();
  late final ContactsService _contactsService = ContactsService();
  final _sms = SmsService();
  List<EmergencyContact> _latestContacts = [];

  // Instant share state
  Position? _currentPosition;
  String? _currentMapUrl;
  bool _isFetchingLocation = false;
  String? _locationError;

  // Timed session state
  Duration _selectedDuration = const Duration(minutes: 30);
  bool _isStartingTimed = false;
  String? _activeSessionId;
  DateTime? _expiresAt;

  static const _durationOptions = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];
  @override
  void initState() {
    super.initState();
    // Ask for SMS permission now, so it is already allowed when SOS needs it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _sms.ensurePermission(),
    );
  }

  @override
  void dispose() {
    if (_service.isActive) {
      _service.stopSharing();
    }
    super.dispose();
  }

  String _labelFor(Duration d) =>
      d.inHours >= 1 ? '${d.inHours} hr' : '${d.inMinutes} min';

  /// Fetches actual GPS latitude and longitude, generating a universal map URL.
  Future<void> _fetchCurrentLocation({bool autoShare = false}) async {
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      final position = await _service.getCurrentLocation();
      final url = LocationShareService.formatMapUrl(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentMapUrl = url;
          _isFetchingLocation = false;
        });

        if (autoShare) {
          await _triggerNativeShare(url, position);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _locationError = errorMsg;
          _isFetchingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  String? get _currentUserName {
    try {
      return FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {
      return null;
    }
  }

  /// Triggers the device's native sharing mechanism.
  Future<void> _triggerNativeShare(String mapUrl, Position? pos) async {
    final name = _currentUserName;
    final text = LocationShareService.buildShareMessage(
      latitude: pos?.latitude ?? 0.0,
      longitude: pos?.longitude ?? 0.0,
      name: name,
    );

    try {
      // ignore: deprecated_member_use
      await Share.share(text, subject: 'My Current Location - SafeHer');
    } catch (_) {
      // Graceful fallback to clipboard if native share sheet is unavailable on current platform
      await Clipboard.setData(ClipboardData(text: mapUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Native share unavailable. Map link copied to clipboard!',
            ),
          ),
        );
      }
    }
  }

  /// Opens the universal map URL in Google Maps, Apple Maps, or the default browser.
  Future<void> _openMapUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open external map application.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error launching map: $e')));
      }
    }
  }

  /// Copies the clean map URL to the clipboard.
  Future<void> _copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Map link copied to clipboard!')),
      );
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _smsText() => LocationShareService.buildShareMessage(
    latitude: _currentPosition?.latitude ?? 0.0,
    longitude: _currentPosition?.longitude ?? 0.0,
    name: _currentUserName,
  );

  /// Sends the location straight to the given contacts by SMS.
  Future<void> _sendSmsTo(List<EmergencyContact> contacts) async {
    if (contacts.isEmpty) {
      _snack('No emergency contacts to send to.');
      return;
    }
    if (_currentPosition == null) return;

    final allowed = await _sms.ensurePermission();
    if (!allowed) {
      _snack(
        'SMS permission is needed to send your location. Allow it in the phone settings, or use WhatsApp.',
      );
      return;
    }

    final text = _smsText();
    int sent = 0;
    for (final c in contacts) {
      if (await _sms.send(c.phone, text)) sent++;
    }
    _snack(
      sent == contacts.length
          ? 'Location sent by SMS to $sent contact${sent == 1 ? '' : 's'}.'
          : 'Sent to $sent of ${contacts.length} contacts. Check the other phone numbers.',
    );
  }

  /// SMS button next to one contact.
  Future<void> _shareViaSms(EmergencyContact contact, String url) =>
      _sendSmsTo([contact]);

  /// One tap: get the GPS location and SMS it to every contact.
  Future<void> _sendToAllContacts() async {
    await _fetchCurrentLocation();
    if (_currentPosition == null) return; // the error is already shown
    final List<EmergencyContact> contacts = _latestContacts.isNotEmpty
        ? _latestContacts
        : (widget.contactsStream != null
              ? <EmergencyContact>[]
              : await _contactsService.getContactsOnce());
    await _sendSmsTo(contacts);
  }

  /// Opens WhatsApp with recipient phone and prefilled message.
  Future<void> _shareViaWhatsApp(EmergencyContact contact, String url) async {
    final name = _currentUserName;
    final text = LocationShareService.buildShareMessage(
      latitude: _currentPosition?.latitude ?? 0.0,
      longitude: _currentPosition?.longitude ?? 0.0,
      name: name,
    );
    final cleanPhone = contact.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final waUri = Uri.parse(
      cleanPhone.isNotEmpty
          ? 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}'
          : 'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );

    try {
      final launched = await launchUrl(
        waUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $e')));
      }
    }
  }

  /// Starts a timed live location sharing session.
  Future<void> _startTimedSharing() async {
    setState(() => _isStartingTimed = true);
    try {
      final name = _currentUserName ?? 'A SafeHer user';
      final sessionId = await _service.startSharing(
        sharerName: name,
        duration: _selectedDuration,
      );
      final initialPos = await _service.getCurrentLocation();
      final url = LocationShareService.formatMapUrl(
        initialPos.latitude,
        initialPos.longitude,
      );

      setState(() {
        _activeSessionId = sessionId;
        _expiresAt = DateTime.now().add(_selectedDuration);
        _currentPosition = initialPos;
        _currentMapUrl = url;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not start sharing: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingTimed = false);
    }
  }

  Future<void> _stopTimedSharing() async {
    await _service.stopSharing();
    setState(() {
      _activeSessionId = null;
      _expiresAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Location')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Instant Share Current Location
            _buildInstantShareCard(),

            const SizedBox(height: AppSpacing.xl),

            // Section 2: Share with Emergency Contacts
            _buildEmergencyContactsSection(),

            const SizedBox(height: AppSpacing.xl),

            // Section 3: Timed Live Sharing (Continuous tracking)
            _activeSessionId == null
                ? _buildTimedSetupCard()
                : _buildTimedActiveCard(),
          ],
        ),
      ),
    );
  }

  /// Card for fetching and sharing current GPS location immediately.
  Widget _buildInstantShareCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.my_location,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Current Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Sends real GPS coordinates as a universal map link',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_locationError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.dangerLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_currentPosition != null && _currentMapUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'GPS: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _currentMapUrl!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryLight,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Universal link — opens directly in Google Maps, Apple Maps, or any browser.',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                    onPressed: () =>
                        _triggerNativeShare(_currentMapUrl!, _currentPosition),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filledTonal(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy Link',
                  onPressed: () => _copyToClipboard(_currentMapUrl!),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filledTonal(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: 'Open in Maps',
                  onPressed: () => _openMapUrl(_currentMapUrl!),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sms_outlined, size: 16),
                label: const Text('Send to All Contacts by SMS'),
                onPressed: _sendToAllContacts,
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isFetchingLocation
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.location_searching, size: 18),
                label: Text(
                  _isFetchingLocation
                      ? 'Acquiring GPS location…'
                      : 'Send to All Contacts by SMS',
                ),
                onPressed: _isFetchingLocation ? null : _sendToAllContacts,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Section displaying emergency contacts with direct SMS/WhatsApp share triggers.
  Widget _buildEmergencyContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Share with Emergency Contacts',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'SMS sends your location straight to the contact. WhatsApp opens the chat with your location filled in - you just tap Send there.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<EmergencyContact>>(
          stream: widget.contactsStream ?? _contactsService.watchContacts(),
          builder: (context, snapshot) {
            final contacts = snapshot.data ?? [];
            _latestContacts = contacts;
            if (contacts.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'No emergency contacts configured yet. Add trusted contacts in the Emergency Contacts tab to share with them quickly.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: contacts.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          contact.name.isNotEmpty
                              ? contact.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              contact.phone,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        icon: const Icon(Icons.sms_outlined, size: 14),
                        label: const Text(
                          'SMS',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () async {
                          if (_currentMapUrl == null) {
                            await _fetchCurrentLocation();
                          }
                          if (_currentMapUrl != null) {
                            await _shareViaSms(contact, _currentMapUrl!);
                          }
                        },
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 14),
                        label: const Text(
                          'WhatsApp',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () async {
                          if (_currentMapUrl == null) {
                            await _fetchCurrentLocation();
                          }
                          if (_currentMapUrl != null) {
                            await _shareViaWhatsApp(contact, _currentMapUrl!);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// Setup card for timed continuous live sharing.
  Widget _buildTimedSetupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timed Live Location Sharing',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Share your position continuously for a set duration. Live updates stop automatically when time runs out or when you stop it.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Duration:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            children: _durationOptions.map((d) {
              final isSelected = d == _selectedDuration;
              return ChoiceChip(
                label: Text(_labelFor(d)),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                onSelected: (_) => setState(() => _selectedDuration = d),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isStartingTimed ? null : _startTimedSharing,
              child: _isStartingTimed
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start Timed Sharing'),
            ),
          ),
        ],
      ),
    );
  }

  /// Active card when timed sharing is ongoing.
  Widget _buildTimedActiveCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Timed sharing is active',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                    if (_expiresAt != null)
                      Text(
                        'Active until ${_expiresAt!.hour.toString().padLeft(2, '0')}:${_expiresAt!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_currentMapUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                _currentMapUrl!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share Link'),
                    onPressed: () =>
                        _triggerNativeShare(_currentMapUrl!, _currentPosition),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filledTonal(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copyToClipboard(_currentMapUrl!),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filledTonal(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => _openMapUrl(_currentMapUrl!),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _stopTimedSharing,
              child: const Text('Stop Sharing'),
            ),
          ),
        ],
      ),
    );
  }
}
