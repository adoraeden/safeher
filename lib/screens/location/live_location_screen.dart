import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/api_config.dart';
import '../../services/location_share_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  final _service = LocationShareService();
  Duration _selectedDuration = const Duration(minutes: 30);
  bool _isStarting = false;
  String? _activeSessionId;
  DateTime? _expiresAt;

  static const _durationOptions = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  @override
  void dispose() {
    if (_service.isActive) {
      _service.stopSharing();
    }
    super.dispose();
  }

  String _labelFor(Duration d) =>
      d.inHours >= 1 ? '${d.inHours} hr' : '${d.inMinutes} min';

  Future<void> _start() async {
    setState(() => _isStarting = true);
    try {
      final name =
          FirebaseAuth.instance.currentUser?.displayName ?? 'A SafeHer user';
      final sessionId = await _service.startSharing(
        sharerName: name,
        duration: _selectedDuration,
      );
      setState(() {
        _activeSessionId = sessionId;
        _expiresAt = DateTime.now().add(_selectedDuration);
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
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _stop() async {
    await _service.stopSharing();
    setState(() {
      _activeSessionId = null;
      _expiresAt = null;
    });
  }

  String get _shareLink =>
      '${ApiConfig.baseUrl}/share.html?id=$_activeSessionId';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Location Sharing')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _activeSessionId == null ? _buildSetup() : _buildActive(),
      ),
    );
  }

  Widget _buildSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Share your live location with anyone who has this link, for a limited time. Sharing stops automatically when time runs out, or the moment you leave this screen.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Share for how long?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(
          onPressed: _isStarting ? null : _start,
          child: _isStarting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Start sharing'),
        ),
      ],
    );
  }

  Widget _buildActive() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.success),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.success, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Sharing your live location',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Until ${_expiresAt!.hour.toString().padLeft(2, '0')}:${_expiresAt!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Share this link',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _shareLink,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy,
                  size: 18,
                  color: AppColors.primaryLight,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _shareLink));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Link copied')));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Works for anyone on the same network as your backend — send it via any messaging app you like.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _stop,
            child: const Text('Stop sharing'),
          ),
        ),
      ],
    );
  }
}
