import 'package:flutter/material.dart';
import 'game_screen.dart';
import '../networking/network_manager.dart';

const int hostPort = 8080;

class HostScreen extends StatelessWidget {
  const HostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      body: Center(
        child: FutureBuilder<String>(
          future: NetworkManager((_) {}).getLocalIp(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
            } else if (!snapshot.hasData || snapshot.data == null) {
              return const Text('Could not get IP address', style: TextStyle(color: Colors.red));
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Your IP: ${snapshot.data}:$hostPort',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(isHost: true, port: hostPort),
                    ),
                  ),
                  child: const Text('Start Hosting'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}