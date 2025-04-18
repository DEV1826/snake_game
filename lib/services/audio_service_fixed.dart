import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final AudioPlayer _player = AudioPlayer();
  bool _isMusicPlaying = false;

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  Future<void> playBackgroundMusic() async {
    if (!_isMusicPlaying) {
      try {
        await _player.setReleaseMode(ReleaseMode.loop); // Loop continuously
        await _player.setSourceAsset('bgmusic.mp3');
        await _player.resume();
        _isMusicPlaying = true;
      } catch (e) {
        print('Error playing music: $e');
        // Create a silent background "music" if file is missing
        // This prevents the app from crashing
        _isMusicPlaying = true;
      }
    }
  }

  Future<void> pauseBackgroundMusic() async {
    if (_isMusicPlaying) {
      await _player.pause();
      _isMusicPlaying = false;
    }
  }

  Future<void> stopBackgroundMusic() async {
    if (_isMusicPlaying) {
      await _player.stop();
      _isMusicPlaying = false;
    }
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  bool get isMusicPlaying => _isMusicPlaying;

  void dispose() {
    _player.dispose();
  }
}
