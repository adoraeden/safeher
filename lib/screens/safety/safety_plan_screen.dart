import 'package:flutter/material.dart';

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
  final _notesController = TextEditingController();
  final _newPlaceController = TextEditingController();
  List<String> _safePlaces = [];
  Map<String, bool> _checklist = Map.from(SafetyPlan.defaultChecklist);
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _newPlaceController.dispose();
    super.dispose();
  }

  void _addPlace() {
    final text = _newPlaceController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _safePlaces = [..._safePlaces, text];
      _newPlaceController.clear();
    });
  }

  void _removePlace(int index) {
    setState(() {
      _safePlaces = List.of(_safePlaces)..removeAt(index);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _service.savePlan(
        SafetyPlan(
          safePlaces: _safePlaces,
          personalNotes: _notesController.text.trim(),
          checklist: _checklist,
        ),
      );
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Safety Plan')),
      body: StreamBuilder<SafetyPlan>(
        stream: _service.watchPlan(),
        builder: (context, snapshot) {
          if (snapshot.hasData && !_initialized) {
            _safePlaces = List.from(snapshot.data!.safePlaces);
            _notesController.text = snapshot.data!.personalNotes;
            _checklist = Map.from(snapshot.data!.checklist);
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
                _SectionCard(
                  title: 'Safe places',
                  icon: Icons.home_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Homes, workplaces, or venues you can go to if you feel unsafe.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._safePlaces.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppColors.primaryLight,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => _removePlace(entry.key),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newPlaceController,
                              decoration: const InputDecoration(
                                hintText: 'Add a safe place',
                              ),
                              onSubmitted: (_) => _addPlace(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: AppColors.primary,
                            ),
                            onPressed: _addPlace,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Personal notes',
                  icon: Icons.edit_note_outlined,
                  child: TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Anything else worth remembering — allergies, medical notes, a code word with a friend, etc.',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Preparedness checklist',
                  icon: Icons.checklist_outlined,
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
                            onChanged: (v) => setState(
                              () => _checklist[entry.key] = v ?? false,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save safety plan'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
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
              Icon(icon, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
