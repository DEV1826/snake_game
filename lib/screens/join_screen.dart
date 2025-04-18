import 'package:flutter/material.dart';
import 'game_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final TextEditingController _ipController = TextEditingController();
  final int port = 35555; // Using a higher port that works better on real devices

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                hintText: 'Enter Host IP',
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white24,
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    isHost: false,
                    hostIp: _ipController.text,
                    port: port,
                  ),
                ),
              ),
              child: const Text('Join Game'),
            ),
          ],
        ),
      ),
    );
  }
}