import 'package:flutter/material.dart';

class MultiplayerMenuScreen extends StatelessWidget {
  const MultiplayerMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Multiplayer'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            
            Image.asset(
              'assets/logo.jpg',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
            
            const SizedBox(height: 50),
            
            // Host Game button
            _buildMenuButton(
              context: context,
              icon: Icons.videogame_asset,
              label: 'HOST GAME',
              onTap: () => Navigator.pushNamed(context, '/host_setup'),
            ),
            
            const SizedBox(height: 16),
            
            // Join Game button
            _buildMenuButton(
              context: context,
              icon: Icons.search,
              label: 'JOIN GAME',
              onTap: () => Navigator.pushNamed(context, '/find_games'),
            ),
            
            const SizedBox(height: 16),
            
            // Back button
            _buildMenuButton(
              context: context,
              icon: Icons.arrow_back,
              label: 'BACK',
              color: Colors.grey[700],
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return SizedBox(
      width: 250,
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
      ),
    );
  }
}
