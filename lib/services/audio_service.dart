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
        // Try to play the background music file
        try {
          await _player.setSourceAsset('bgmusic.mp3');
          await _player.resume();
        } catch (assetError) {
          // If the specific asset is missing, try a fallback
          try {
            await _player.setSourceAsset('music.mp3');
            await _player.resume();
          } catch (fallbackError) {
            // Both files are missing, just continue without music
            print('Background music files not found: $fallbackError');
          }
        }
        _isMusicPlaying = true;
      } catch (e) {
        print('Error playing music: $e');
        // Continue without music if there's an error
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
