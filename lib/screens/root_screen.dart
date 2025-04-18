import 'package:flutter/material.dart';
import 'splash_screen.dart';
import '../services/audio_service.dart';
import 'menu_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final AudioService _audioService = AudioService();
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Try to play background music, but don't crash if there's an error
    try {
      _audioService.playBackgroundMusic();
    } catch (e) {
      print('Error playing background music: $e');
      // Continue without music if there's an error
    }
    
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _showSplash = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? const SplashScreen() : const MenuScreen();
  }
}
