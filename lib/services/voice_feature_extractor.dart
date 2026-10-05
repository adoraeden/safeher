import 'dart:math' as math;
import 'dart:typed_data';

import '../models/voice_profile.dart';

class VoiceValidationResult {
  final bool isValid;
  final String? errorMessage;
  final VoiceProfile? profile;

  const VoiceValidationResult.success(this.profile)
    : isValid = true,
      errorMessage = null;

  const VoiceValidationResult.failure(this.errorMessage)
    : isValid = false,
      profile = null;
}

/// Classical, non-ML acoustic feature extraction: pitch (via autocorrelation)
/// and energy, frame by frame. This is real signal processing, not a trained
/// model — see documentation for limitations and practical design.
class VoiceFeatureExtractor {
  /// Validates the audio sample for duration, volume, and clarity,
  /// returning descriptive feedback on failure or the extracted VoiceProfile on success.
  static VoiceValidationResult validateAndExtractFromWav(
    Uint8List wavBytes, {
    int sampleRate = 16000,
  }) {
    // Assumes a standard 44-byte PCM WAV header (produced by `record` with AudioEncoder.wav)
    if (wavBytes.length < 44) {
      return const VoiceValidationResult.failure(
        'Audio file is empty or corrupted.',
      );
    }
    final pcmBytes = wavBytes.sublist(44);

    final samples = <double>[];
    for (int i = 0; i + 1 < pcmBytes.length; i += 2) {
      final raw = pcmBytes[i] | (pcmBytes[i + 1] << 8);
      final signed = raw >= 32768 ? raw - 65536 : raw;
      samples.add(signed / 32768.0);
    }
    if (samples.isEmpty) {
      return const VoiceValidationResult.failure('No audio data was recorded.');
    }

    // Normalize overall volume before analysis. Raw energy is sensitive to
    // mic distance and speaking volume, not just clarity - a clear phrase
    // spoken from across the room can have far less raw energy than a mushy
    // one spoken right into the mic. Bringing every clip to a consistent
    // target loudness first means the checks below measure clarity, not
    // distance.
    final double rms = () {
      double sumSquares = 0;
      for (final s in samples) {
        sumSquares += s * s;
      }
      return sumSquares > 0 ? math.sqrt(sumSquares / samples.length) : 0.0;
    }();

    const double noiseFloor = 0.0006; // below this, treat as true silence - don't amplify noise into fake "speech"
    const double targetRms = 0.06; // comfortable normalized speaking level
    const double maxGain =
        14.0; // cap so pure background hiss can't be boosted into a false pass

    if (rms > noiseFloor) {
      final gain = (targetRms / rms).clamp(1.0, maxGain);
      if (gain > 1.0) {
        for (int i = 0; i < samples.length; i++) {
          samples[i] = (samples[i] * gain).clamp(-1.0, 1.0);
        }
      }
    }

    final durationSeconds = samples.length / sampleRate;
    if (durationSeconds < 0.6) {
      return const VoiceValidationResult.failure(
        'Recording was too short. Please speak the full phrase clearly.',
      );
    }

    const frameSize = 480; // 30ms at 16kHz
    final pitches = <double>[];
    double totalEnergy = 0;
    int frameCount = 0;
    int speechFrameCount = 0;

    for (
      int start = 0;
      start + frameSize < samples.length;
      start += frameSize
    ) {
      final frame = samples.sublist(start, start + frameSize);
      final energy =
          frame.map((s) => s * s).reduce((a, b) => a + b) / frame.length;
      totalEnergy += energy;
      frameCount++;

      if (energy < 0.0005) continue; // near-silent frame, skip
      speechFrameCount++;

      final pitch = _estimatePitch(frame, sampleRate);
      if (pitch != null && pitch > 60 && pitch < 500) {
        pitches.add(pitch);
      }
    }

    if (frameCount == 0 || speechFrameCount < 4) {
      return const VoiceValidationResult.failure(
        'Audio is too quiet. Please speak up closer to the mic.',
      );
    }

    final avgEnergy = totalEnergy / frameCount;
    if (avgEnergy < 0.0006) {
      return const VoiceValidationResult.failure(
        'Recording was too quiet. Please speak at normal volume.',
      );
    }

    if (pitches.isEmpty || pitches.length < 3) {
      return const VoiceValidationResult.failure(
        'Voice was unclear or mostly silence. Please speak naturally.',
      );
    }

    final avgPitch = pitches.reduce((a, b) => a + b) / pitches.length;
    final variance =
        pitches
            .map((p) => (p - avgPitch) * (p - avgPitch))
            .reduce((a, b) => a + b) /
        pitches.length;

    final profile = VoiceProfile(
      avgPitchHz: avgPitch,
      pitchVariance: variance,
      avgEnergy: avgEnergy,
      durationSeconds: durationSeconds,
    );

    return VoiceValidationResult.success(profile);
  }

  static VoiceProfile? extractFromWav(
    Uint8List wavBytes, {
    int sampleRate = 16000,
  }) {
    return validateAndExtractFromWav(wavBytes, sampleRate: sampleRate).profile;
  }

  /// Autocorrelation pitch detection, searched over the human voice
  /// fundamental-frequency range (roughly 70-400 Hz).
  static double? _estimatePitch(List<double> frame, int sampleRate) {
    final minLag = (sampleRate / 400).floor();
    final maxLag = (sampleRate / 70).floor();
    if (maxLag >= frame.length) return null;

    double bestCorrelation = 0;
    int bestLag = -1;

    for (int lag = minLag; lag <= maxLag; lag++) {
      double correlation = 0;
      for (int i = 0; i < frame.length - lag; i++) {
        correlation += frame[i] * frame[i + lag];
      }
      if (correlation > bestCorrelation) {
        bestCorrelation = correlation;
        bestLag = lag;
      }
    }

    if (bestLag <= 0) return null;
    return sampleRate / bestLag;
  }
}
