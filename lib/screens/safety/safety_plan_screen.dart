import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/safety_plan.dart';
import '../../services/safety_plan_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class SafetyPlanScreen extends StatefulWidget {
  const SafetyPlanScreen({super.key});

  @override
  State<SafetyPlanScreen> createState() => _SafetyPlanScreenState();
}

class _SafetyPlanScreenState extends State<SafetyPlanScreen> {
  final _service = SafetyPlanService();
  final _medicalController = TextEditingController();
  final _distressController = TextEditingController();
  final _notesController = TextEditingController();

  List<SafeHaven> _havens = [];
  List<CommuteRoute> _routes = [];
  Map<String, bool> _checklist = Map.from(SafetyPlan.defaultChecklist);
  bool _initialized = false;
  bool _isSaving = false;
  bool _dirty = false;

  @override
  void dispose() {
    _medicalController.dispose();
    _distressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<List<String>?> _ask(String title, List<_FieldSpec> fields) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _EntrySheet(title: title, fields: fields),
    );
  }

  Future<void> _addHaven() async {
    final res = await _ask('Add a safe place', const [
      _FieldSpec('Place name', 'e.g. 24/7 pharmacy, friend\'s home'),
      _FieldSpec('Address or landmark', 'e.g. Near the main gate, MG Road'),
      _FieldSpec(
        'Notes or entry code',
        'e.g. Guard at the gate, open 24/7',
        maxLines: 2,
      ),
    ]);
    if (res == null || !mounted) return;
    setState(() {
      _havens = [
        ..._havens,
        SafeHaven(name: res[0], address: res[1], notes: res[2]),
      ];
      _dirty = true;
    });
  }

  Future<void> _addRoute() async {
    final res = await _ask('Add a commute route', const [
      _FieldSpec('Route name', 'e.g. Home to college'),
      _FieldSpec(
        'Checkpoints and notes',
        'e.g. Metro station, pharmacy near gate 2, avoid the back lane',
        maxLines: 3,
      ),
    ]);
    if (res == null || !mounted) return;
    setState(() {
      _routes = [..._routes, CommuteRoute(name: res[0], details: res[1])];
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _service.savePlan(
        SafetyPlan(
          safeHavens: _havens,
          routes: _routes,
          medicalInfo: _medicalController.text.trim(),
          distressNotes: _distressController.text.trim(),
          personalNotes: _notesController.text.trim(),
          checklist: _checklist,
        ),
      );
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Safety plan saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _planText({required bool includePrivate}) {
    final b = StringBuffer('My SafeHer Safety Plan\n');
    if (_havens.isNotEmpty) {
      b.writeln('\nSafe places:');
      for (final h in _havens) {
        b.write('- ${h.name}');
        if (h.address.isNotEmpty) b.write(' (${h.address})');
        if (h.notes.isNotEmpty) b.write(' - ${h.notes}');
        b.writeln();
      }
    }
    if (_routes.isNotEmpty) {
      b.writeln('\nCommute routes:');
      for (final r in _routes) {
        b.write('- ${r.name}');
        if (r.details.isNotEmpty) b.write(': ${r.details}');
        b.writeln();
      }
    }
    if (includePrivate) {
      if (_medicalController.text.trim().isNotEmpty) {
        b.writeln('\nMedical info:\n${_medicalController.text.trim()}');
      }
      if (_distressController.text.trim().isNotEmpty) {
        b.writeln('\nDistress codes:\n${_distressController.text.trim()}');
      }
    }
    if (_notesController.text.trim().isNotEmpty) {
      b.writeln('\nNotes:\n${_notesController.text.trim()}');
    }
    return b.toString().trim();
  }

  Future<void> _share() async {
    final hasPrivate =
        _medicalController.text.trim().isNotEmpty ||
        _distressController.text.trim().isNotEmpty;
    var includePrivate = false;

    if (hasPrivate) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Include private details?'),
          content: const Text(
            'Your medical info and distress codes are private. Share them only with someone you trust.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'leave'),
              child: const Text('Leave them out'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'include'),
              child: const Text('Include'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      includePrivate = choice == 'include';
    }

    final text = _planText(includePrivate: includePrivate);
    if (text == 'My SafeHer Safety Plan') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add something to your plan first.')),
        );
      }
      return;
    }
    // ignore: deprecated_member_use
    await Share.share(text, subject: 'My SafeHer Safety Plan');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Safety Plan')),
      body: StreamBuilder<SafetyPlan>(
        stream: _service.watchPlan(),
        builder: (context, snapshot) {
          if (snapshot.hasData && !_initialized) {
            final plan = snapshot.data!;
            _havens = List.from(plan.safeHavens);
            _routes = List.from(plan.routes);
            _medicalController.text = plan.medicalInfo;
            _distressController.text = plan.distressNotes;
            _notesController.text = plan.personalNotes;
            _checklist = Map.from(plan.checklist);
            _initialized = true;
          }
          if (!_initialized &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppSpacing.md),
                _buildReadiness(),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Safe places',
                  icon: Icons.location_on_outlined,
                  color: AppColors.success,
                  trailing: _AddButton(label: 'Add', onTap: _addHaven),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Places you can reach quickly if you feel unsafe: a 24/7 shop, a friend\'s home, a police station, a campus security booth.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_havens.isEmpty)
                        const _EmptyHint('No safe places added yet.')
                      else
                        ..._havens.asMap().entries.map(
                          (e) => _ItemTile(
                            icon: Icons.shield_outlined,
                            color: AppColors.success,
                            title: e.value.name,
                            lines: [e.value.address, e.value.notes],
                            onDelete: () => setState(() {
                              _havens = List.of(_havens)..removeAt(e.key);
                              _dirty = true;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Routine routes and checkpoints',
                  icon: Icons.near_me_outlined,
                  color: AppColors.primaryLight,
                  trailing: _AddButton(label: 'Add route', onTap: _addRoute),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your regular trips and the safe stops along the way.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_routes.isEmpty)
                        const _EmptyHint('No routes added yet.')
                      else
                        ..._routes.asMap().entries.map(
                          (e) => _ItemTile(
                            icon: Icons.route_outlined,
                            color: AppColors.primaryLight,
                            title: e.value.name,
                            lines: [e.value.details],
                            onDelete: () => setState(() {
                              _routes = List.of(_routes)..removeAt(e.key);
                              _dirty = true;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Medical and first responder info',
                  icon: Icons.favorite_outline,
                  color: AppColors.dangerLight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blood group, allergies, conditions or medicines that paramedics should know.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _medicalController,
                        maxLines: 4,
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Blood group O+, penicillin allergy, asthma inhaler in my bag',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const _PrivacyNote(
                        'Stored in your account only. It is never added to SOS messages.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Discreet distress codes',
                  icon: Icons.record_voice_over_outlined,
                  color: AppColors.warning,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Secret phrases you share with family or friends so you can ask for help without anyone noticing.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _distressController,
                        maxLines: 4,
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(
                          hintText: 'e.g. If I text "Did you feed the cat?" it means I need help now',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const _PrivacyNote(
                        'Keep this one private. Do not use it as your Voice Guard phrase.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Other notes',
                  icon: Icons.edit_note_outlined,
                  color: AppColors.primaryLight,
                  child: TextField(
                    controller: _notesController,
                    maxLines: 3,
                    onChanged: (_) => _markDirty(),
                    decoration: const InputDecoration(
                      hintText:
                          'Anything else worth remembering about your safety.',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Preparedness checklist',
                  icon: Icons.checklist_outlined,
                  color: AppColors.success,
                  child: Column(
                    children: _checklist.entries
                        .map(
                          (entry) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            value: entry.value,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() {
                              _checklist[entry.key] = v ?? false;
                              _dirty = true;
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_dirty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'You have unsaved changes',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save safety plan'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share plan'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
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
            AppColors.success.withValues(alpha: 0.18),
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
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: AppColors.success,
              ),
              SizedBox(width: 6),
              Text(
                'PERSONAL READINESS PLAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'My safety plan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Plan your safe places, routes, medical details and distress codes now, so you know what to do in any situation.',
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

  Widget _buildReadiness() {
    final done = _checklist.values.where((v) => v).length;
    final total = _checklist.length;
    final progress = total == 0 ? 0.0 : done / total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Readiness',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$done of $total checklist items done',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldSpec {
  final String label;
  final String hint;
  final int maxLines;
  const _FieldSpec(this.label, this.hint, {this.maxLines = 1});
}

class _EntrySheet extends StatefulWidget {
  final String title;
  final List<_FieldSpec> fields;
  const _EntrySheet({required this.title, required this.fields});

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late final List<TextEditingController> _controllers = widget.fields
      .map((_) => TextEditingController())
      .toList();
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_controllers.first.text.trim().isEmpty) {
      setState(() => _error = '${widget.fields.first.label} is required');
      return;
    }
    Navigator.pop(context, _controllers.map((c) => c.text.trim()).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < widget.fields.length; i++) ...[
                Text(
                  widget.fields[i].label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _controllers[i],
                  autofocus: i == 0,
                  maxLines: widget.fields[i].maxLines,
                  decoration: InputDecoration(hintText: widget.fields[i].hint),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.dangerLight,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Add'),
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

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  final String text;
  const _PrivacyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.lock_outline,
            size: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;
  final VoidCallback onDelete;

  const _ItemTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final details = lines.where((l) => l.trim().isNotEmpty).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                for (final d in details)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
