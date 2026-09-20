import 'package:audioplayers/audioplayers.dart';

class AlarmService {
  final _player = AudioPlayer();

  Future<void> start() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1.0);
    await _player.play(AssetSource('sounds/siren.wav'));
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
