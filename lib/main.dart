import 'package:flutter/material.dart';
import 'screens/root_screen.dart';
import 'screens/game_screen.dart';
import 'screens/create_lobby_screen.dart';
import 'screens/find_games_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake Game',
      theme: ThemeData(
        primaryColor: const Color(0xFF001F3F), // Navy blue
        scaffoldBackgroundColor: const Color(0xFF001F3F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF001F3F),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange, // Button color
            foregroundColor: Colors.white, // Text color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10), // Rounded corners
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
      ),
      // Define all routes for the app
      initialRoute: '/',
      routes: {
        '/': (context) => const RootScreen(),
        '/game': (context) => const GameScreen(isHost: true, playerName: 'Player', port: 35555),
        '/create_lobby': (context) => const CreateLobbyScreen(),
        '/find_games': (context) => const FindGamesScreen(playerName: 'Player'),
      },
    );
  }
}