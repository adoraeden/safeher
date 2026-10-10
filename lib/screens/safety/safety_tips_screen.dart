import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/safety_plan_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class _Category {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  const _Category(this.id, this.title, this.icon, this.color);
}

const _categories = [
  _Category(
    'travel',
    'Traveling Alone',
    Icons.directions_walk,
    AppColors.primaryLight,
  ),
  _Category(
    'transit',
    'Public Transport',
    Icons.directions_bus_outlined,
    AppColors.accent,
  ),
  _Category(
    'night',
    'Night Travel',
    Icons.nightlight_outlined,
    AppColors.warning,
  ),
  _Category(
    'online',
    'Online Safety',
    Icons.shield_outlined,
    AppColors.primaryLight,
  ),
  _Category('home', 'At Home', Icons.home_outlined, AppColors.success),
  _Category('work', 'College & Work', Icons.school_outlined, AppColors.accent),
  _Category(
    'emergency',
    'Emergencies',
    Icons.emergency_outlined,
    AppColors.dangerLight,
  ),
];

_Category _categoryById(String id) =>
    _categories.firstWhere((c) => c.id == id, orElse: () => _categories.first);

class _Tip {
  final String id;
  final String categoryId;
  final String title;
  final String body;
  final List<String> steps;
  final bool critical;
  const _Tip({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.body,
    this.steps = const [],
    this.critical = false,
  });
}

const _tips = [
  // ── Traveling alone ──
  _Tip(
    id: 'travel-share',
    categoryId: 'travel',
    title: 'Share your trip before you leave',
    body: 'Before stepping out, start a live location session with someone you trust so they can follow your journey.',
    steps: [
      'Open Share Location in SafeHer and start a timed session.',
      'Tell your contact when you expect to arrive.',
      'Stop sharing once you have arrived safely.',
    ],
    critical: true,
  ),
  _Tip(
    id: 'travel-cab',
    categoryId: 'travel',
    title: 'Check your cab before you get in',
    body: 'Match the car number, driver name and photo with your booking before you sit down.',
    steps: [
      'Check the number plate against the app.',
      'Ask the driver "who are you here for?" instead of telling them your name.',
      'Send the trip details to a contact before you start.',
      'If anything does not match, do not get in.',
    ],
    critical: true,
  ),
  _Tip(
    id: 'travel-followed',
    categoryId: 'travel',
    title: 'If you think you are being followed',
    body: 'Do not go home. Head for a busy, lit place and call someone while you walk.',
    steps: [
      'Cross the road or change direction to check.',
      'Walk into a shop, petrol pump, hospital or police station.',
      'Call a contact, or 112 if you feel in danger.',
    ],
    critical: true,
  ),
  _Tip(
    id: 'travel-aware',
    categoryId: 'travel',
    title: 'Stay head-up and aware',
    body: 'Keep one ear free when wearing headphones, and keep your phone in a pocket you can reach fast.',
  ),
  _Tip(
    id: 'travel-instinct',
    categoryId: 'travel',
    title: 'Trust your instincts',
    body: 'If a ride or a situation feels wrong, leave at the next safe opportunity. You do not owe anyone an explanation.',
  ),
  // ── Public transport ──
  _Tip(
    id: 'transit-crowd',
    categoryId: 'transit',
    title: 'Unwanted touching in a crowd',
    body: 'Move away, speak loudly and clearly, and ask people around you for help. Speaking up draws attention to the person, not to you.',
    steps: [
      'Say loudly: "Stop touching me" so others hear.',
      'Move towards the driver, conductor or other women.',
      'Note the bus, train or station and report it, or call 112.',
    ],
    critical: true,
  ),
  _Tip(
    id: 'transit-seat',
    categoryId: 'transit',
    title: 'Choose where you sit',
    body: 'Sit near the driver or other passengers, or use the ladies coach or seats where they are available.',
  ),
  _Tip(
    id: 'transit-stop',
    categoryId: 'transit',
    title: 'Plan your stop and your way home',
    body: 'Know where you get off and how you will get home. Avoid empty stops late at night and arrange a pickup if you can.',
  ),
  // ── Night travel ──
  _Tip(
    id: 'night-route',
    categoryId: 'night',
    title: 'Take the lit, busy route',
    body: 'Stick to well-lit, busier roads even if they take a little longer. Skip shortcuts through empty areas.',
    critical: true,
  ),
  _Tip(
    id: 'night-arrival',
    categoryId: 'night',
    title: 'Tell someone your arrival time',
    body: 'Let a contact know when to expect you, and message them when you have arrived.',
    steps: [
      'Send your expected arrival time before you start.',
      'Message "reached" as soon as you are inside.',
    ],
  ),
  _Tip(
    id: 'night-keys',
    categoryId: 'night',
    title: 'Keys ready before the door',
    body: 'Take out your keys before you reach your building, and look around before you enter.',
  ),
  // ── Online safety ──
  _Tip(
    id: 'online-meet',
    categoryId: 'online',
    title: 'Meeting someone from online',
    body: 'Meet in a public place, tell someone where you will be, and arrange your own way there and back.',
    steps: [
      'Video call first, so you know they are who they say.',
      'Share your live location with a friend for the meeting.',
      'Leave if you feel pressured. You can always say no.',
    ],
    critical: true,
  ),
  _Tip(
    id: 'online-report',
    categoryId: 'online',
    title: 'Report online harassment and fraud',
    body: 'Take screenshots before you block anyone, and do not delete the messages. For online financial fraud call 1930, and report other cybercrime at cybercrime.gov.in.',
    steps: [
      'Save screenshots with dates, names and links.',
      'Call 1930 immediately if money was taken.',
      'File a report at cybercrime.gov.in.',
    ],
    critical: true,
  ),
  _Tip(
    id: 'online-location',
    categoryId: 'online',
    title: 'Keep your location private',
    body: 'Avoid posting your real-time location, and turn off location tags on photos you share publicly.',
  ),
  _Tip(
    id: 'online-passwords',
    categoryId: 'online',
    title: 'Strong passwords and two-step login',
    body: 'Use a different strong password for each account and turn on two-factor authentication where it is offered.',
  ),
  // ── At home ──
  _Tip(
    id: 'home-doors',
    categoryId: 'home',
    title: 'Doors, windows and visitors',
    body: 'Keep doors and windows locked, and do not open to people you do not know. Ask service staff to show ID.',
    critical: true,
  ),
  _Tip(
    id: 'home-delivery',
    categoryId: 'home',
    title: 'Deliveries without giving details',
    body: 'Take deliveries at the door, do not say you live alone, and use a safe pickup point if you can.',
  ),
  _Tip(
    id: 'home-neighbours',
    categoryId: 'home',
    title: 'Know someone nearby',
    body: 'Save a neighbour or nearby friend as a contact who can reach you quickly in an emergency.',
  ),
  // ── College and work ──
  _Tip(
    id: 'work-harass',
    categoryId: 'work',
    title: 'Harassment at college or work',
    body: 'Keep a record of what happened with dates and witnesses. Workplaces and colleges have an Internal Committee under the POSH Act where you can file a complaint.',
    steps: [
      'Write down what happened, when, and who saw it.',
      'Save messages and emails.',
      'Contact the Internal Committee, or call 181 for support.',
    ],
    critical: true,
  ),
  _Tip(
    id: 'work-late',
    categoryId: 'work',
    title: 'Working or studying late',
    body: 'Tell security you are leaving, use the company or college transport if there is any, and avoid walking to empty parking areas alone.',
  ),
  _Tip(
    id: 'work-buddy',
    categoryId: 'work',
    title: 'Use a buddy system',
    body: 'Leave with a colleague or friend when you can, and agree to message each other when you are home.',
  ),
  // ── Emergencies ──
  _Tip(
    id: 'emerg-numbers',
    categoryId: 'emergency',
    title: 'Know your emergency numbers',
    body: '112 is the national emergency number. 181 is the women helpline. Save both so you can dial without thinking.',
    steps: [
      '112: police, fire and ambulance.',
      '181: women helpline.',
      '1930: online financial fraud.',
    ],
    critical: true,
  ),
  _Tip(
    id: 'emerg-features',
    categoryId: 'emergency',
    title: 'Try SOS and Voice Guard while you are safe',
    body: 'Test them once so you know how they work before you need them. Choose a Voice Guard phrase of two or three clear, common words.',
    steps: [
      'Turn on Voice Guard and say your phrase once.',
      'Pick common words, like "save me now".',
      'Make sure at least one emergency contact is saved.',
    ],
    critical: true,
  ),
  _Tip(
    id: 'emerg-contacts',
    categoryId: 'emergency',
    title: 'Keep your emergency contacts current',
    body: 'Keep two or three contacts up to date in the app, and check that their numbers are correct.',
  ),
  _Tip(
    id: 'emerg-address',
    categoryId: 'emergency',
    title: 'Know your exact location',
    body: 'Know your address or the nearest landmark so you can say it quickly when you ask for help.',
  ),
  _Tip(
    id: 'emerg-plan',
    categoryId: 'emergency',
    title: 'Review your Safety Plan before you travel',
    body: 'Look over your safe places and routes before a trip, and update anything that has changed.',
  ),
];

class SafetyTipsScreen extends StatefulWidget {
  const SafetyTipsScreen({super.key});

  @override
  State<SafetyTipsScreen> createState() => _SafetyTipsScreenState();
}

class _SafetyTipsScreenState extends State<SafetyTipsScreen> {
  final _service = SafetyPlanService();
  final _searchController = TextEditingController();
  StreamSubscription<Set<String>>? _savedSub;

  String _categoryId = 'all';
  String _query = '';
  Set<String> _saved = {};
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _savedSub = _service.watchSavedTips().listen((ids) {
      if (mounted) setState(() => _saved = ids);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _savedSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleSaved(String id) async {
    final before = Set<String>.from(_saved);
    final after = Set<String>.from(_saved);
    if (!after.remove(id)) after.add(id);
    setState(() => _saved = after);
    try {
      await _service.setSavedTips(after);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saved = before);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this tip. Try again.')),
      );
    }
  }

  List<_Tip> get _filtered {
    final q = _query.trim().toLowerCase();
    return _tips.where((t) {
      if (_categoryId == 'saved' && !_saved.contains(t.id)) return false;
      if (_categoryId != 'all' &&
          _categoryId != 'saved' &&
          t.categoryId != _categoryId) {
        return false;
      }
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.body.toLowerCase().contains(q) ||
          _categoryById(t.categoryId).title.toLowerCase().contains(q) ||
          t.steps.any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  _Tip get _tipOfTheDay {
    final critical = _tips.where((t) => t.critical).toList();
    final now = DateTime.now();
    final day = now.difference(DateTime(now.year, 1, 1)).inDays;
    return critical[day % critical.length];
  }

  @override
  Widget build(BuildContext context) {
    final tips = _filtered;
    final showDaily = _categoryId == 'all' && _query.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Safety Tips')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search tips, keywords or situations',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildChips(),
          const SizedBox(height: AppSpacing.md),
          if (showDaily) ...[
            _buildTipOfTheDay(),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            '${tips.length} tip${tips.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (tips.isEmpty)
            _buildEmpty()
          else
            ...tips.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _TipCard(
                  tip: t,
                  saved: _saved.contains(t.id),
                  expanded: _expanded.contains(t.id),
                  onToggleSaved: () => _toggleSaved(t.id),
                  onToggleExpanded: () => setState(() {
                    if (!_expanded.remove(t.id)) _expanded.add(t.id);
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withValues(alpha: 0.18),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: AppColors.warning),
              SizedBox(width: 6),
              Text(
                'PRACTICAL SAFETY GUIDE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Safety tips and best practices',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Simple, real-world advice for commutes, nights out, online life and emergencies.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChips() {
    Widget chip(String id, String label, IconData icon) {
      final selected = _categoryId == id;
      return ChoiceChip(
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 16,
          color: selected ? Colors.white : AppColors.textSecondary,
        ),
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
        onSelected: (_) => setState(() => _categoryId = id),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('all', 'All', Icons.apps),
          const SizedBox(width: 8),
          chip('saved', 'Saved (${_saved.length})', Icons.star_outline),
          for (final c in _categories) ...[
            const SizedBox(width: 8),
            chip(c.id, c.title, c.icon),
          ],
        ],
      ),
    );
  }

  Widget _buildTipOfTheDay() {
    final tip = _tipOfTheDay;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.wb_sunny_outlined,
                size: 16,
                color: AppColors.primaryLight,
              ),
              SizedBox(width: 6),
              Text(
                'TIP OF THE DAY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tip.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tip.body,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final message = _categoryId == 'saved' && _query.trim().isEmpty
        ? 'No saved tips yet. Tap the star on a tip to keep it here.'
        : 'No tips match your search.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off,
            size: 32,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final _Tip tip;
  final bool saved;
  final bool expanded;
  final VoidCallback onToggleSaved;
  final VoidCallback onToggleExpanded;

  const _TipCard({
    required this.tip,
    required this.saved,
    required this.expanded,
    required this.onToggleSaved,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final category = _categoryById(tip.categoryId);
    return InkWell(
      onTap: tip.steps.isEmpty ? null : onToggleExpanded,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: tip.critical
                ? AppColors.danger.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon, size: 12, color: category.color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            category.title.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: category.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (tip.critical) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 11,
                          color: AppColors.dangerLight,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Critical',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dangerLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                InkWell(
                  onTap: onToggleSaved,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      saved ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: saved
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tip.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tip.body,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (tip.steps.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (expanded)
                ...tip.steps.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Text(
                    expanded ? 'Hide steps' : 'Show steps',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.primaryLight,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
