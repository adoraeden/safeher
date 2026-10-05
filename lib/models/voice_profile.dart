class VoiceProfile {
  final double avgPitchHz;
  final double pitchVariance;
  final double avgEnergy;
  final double durationSeconds;

  VoiceProfile({
    required this.avgPitchHz,
    required this.pitchVariance,
    required this.avgEnergy,
    required this.durationSeconds,
  });

  Map<String, dynamic> toMap() => {
    'avgPitchHz': avgPitchHz,
    'pitchVariance': pitchVariance,
    'avgEnergy': avgEnergy,
    'durationSeconds': durationSeconds,
  };

  factory VoiceProfile.fromMap(Map<String, dynamic> map) => VoiceProfile(
    avgPitchHz: (map['avgPitchHz'] as num).toDouble(),
    pitchVariance: (map['pitchVariance'] as num).toDouble(),
    avgEnergy: (map['avgEnergy'] as num).toDouble(),
    durationSeconds: (map['durationSeconds'] as num).toDouble(),
  );

  static VoiceProfile average(List<VoiceProfile> profiles) {
    final n = profiles.length;
    return VoiceProfile(
      avgPitchHz: profiles.map((p) => p.avgPitchHz).reduce((a, b) => a + b) / n,
      pitchVariance:
          profiles.map((p) => p.pitchVariance).reduce((a, b) => a + b) / n,
      avgEnergy: profiles.map((p) => p.avgEnergy).reduce((a, b) => a + b) / n,
      durationSeconds:
          profiles.map((p) => p.durationSeconds).reduce((a, b) => a + b) / n,
    );
  }

  /// 0-1 similarity score (1 = identical). Weighted toward pitch, since
  /// that's the more reliable of the two signals we extract.
  double similarityTo(VoiceProfile other) {
    final pitchDiff = (avgPitchHz - other.avgPitchHz).abs() / 200.0;
    final energyDiff =
        (avgEnergy - other.avgEnergy).abs() /
        (avgEnergy.abs() + other.avgEnergy.abs() + 0.001);
    final combined = (pitchDiff * 0.7) + (energyDiff * 0.3);
    return (1.0 - combined).clamp(0.0, 1.0);
  }
}
