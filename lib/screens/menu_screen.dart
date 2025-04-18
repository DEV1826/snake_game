import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'game_screen.dart';
import 'create_lobby_screen.dart';
import 'find_games_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _menuState = 0; // 0: main, 1: multiplayer, 2: difficulty
  String _difficulty = 'Medium';

  @override
  void initState() {
    super.initState();
    // Try to play background music, but don't crash if file is missing
    try {
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
      _audioPlayer.play(AssetSource('music.mp3'));
    } catch (e) {
      print('Error playing background music: $e');
      // Continue without music if there's an error
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildMenu() {
    switch (_menuState) {
      case 1:
        return _buildMultiplayerMenu();
      case 2:
        return _buildDifficultyMenu();
      default:
        return _buildMainMenu();
    }
  }

  Widget _buildMainMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _menuItem(
          'PLAY',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GameScreen(isHost: true, port: 35555, playerName: 'Player'),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        _menuItem(
          'MULTIPLAYER',
          onTap: () => setState(() => _menuState = 1),
        ),
        const SizedBox(height: 30),
        _menuItem(
          'DIFFICULTY: $_difficulty',
          onTap: () => setState(() => _menuState = 2),
        ),
        const SizedBox(height: 30),
        _menuItem(
          'EXIT',
          onTap: () => SystemNavigator.pop(),
        ),
      ],
    );
  }

  Widget _buildMultiplayerMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _menuItem(
          'HOST GAME',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateLobbyScreen()),
          ),
        ),
        const SizedBox(height: 30),
        _menuItem(
          'JOIN GAME',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FindGamesScreen(playerName: 'Player')),
          ),
        ),
        const SizedBox(height: 30),
        _menuItem(
          'BACK',
          onTap: () => setState(() => _menuState = 0),
        ),
      ],
    );
  }

  Widget _buildDifficultyMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _menuItem(
          'EASY',
          onTap: () => setState(() { _difficulty = 'Easy'; _menuState = 0; }),
        ),
        const SizedBox(height: 30),
        _menuItem(
          'MEDIUM',
          onTap: () => setState(() { _difficulty = 'Medium'; _menuState = 0; }),
        ),
        const SizedBox(height: 30),
        _menuItem(
          'HARD',
          onTap: () => setState(() { _difficulty = 'Hard'; _menuState = 0; }),
        ),
        const SizedBox(height: 30),
        _menuItem(
          'BACK',
          onTap: () => setState(() => _menuState = 0),
        ),
      ],
    );
  }

  // Helper method to create menu items with consistent styling
  Widget _menuItem(String text, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          letterSpacing: 1.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'Arial',
          shadows: [
            Shadow(
              blurRadius: 10.0,
              color: Colors.blue.withOpacity(0.7),
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background image
            Image.asset(
              'assets/logo.jpg',
              fit: BoxFit.cover,
            ),
            Container(
              color: Colors.black.withOpacity(0.5),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.transparent),
            ),
            Center(
              child: _buildMenu(),
            ),
          ],
        ),
      ),
    );
  }
}