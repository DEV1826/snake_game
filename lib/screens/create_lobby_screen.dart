import 'package:flutter/material.dart';
import '../networking/simple_network_manager.dart';
import 'host_lobby_screen.dart';

class CreateLobbyScreen extends StatefulWidget {
  const CreateLobbyScreen({Key? key}) : super(key: key);

  @override
  State<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

class _CreateLobbyScreenState extends State<CreateLobbyScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Snake Game');
  final TextEditingController _playerNameController = TextEditingController(text: 'Host');
  int _maxPlayers = 4;

  @override
  void dispose() {
    print('CreateLobbyScreen being disposed');
    _nameController.dispose();
    _playerNameController.dispose();
    
    // Note: We don't need to dispose a network manager here because 
    // we only create it when navigating to the HostLobbyScreen
    // and that screen will handle cleanup if needed
    
    super.dispose();
  }

  void _createLobby() {
    if (_nameController.text.isEmpty || _playerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );

    // Create a new network manager with proper callbacks
    final networkManager = SimpleNetworkManager(
      onGameStateUpdate: (_) {},
      onErrorMessage: (message) {
        // Pop loading dialog if showing
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
        );
      },
    );

    // Initialize network manager and navigate to lobby screen
    networkManager.initialize().then((_) {
      // Pop loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Navigate to the lobby screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HostLobbyScreen(
            networkManager: networkManager,
            playerName: _playerNameController.text,
          ),
        ),
      );
    }).catchError((error) {
      // Pop loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $error'),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Create Game Lobby'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game name field
            const Text(
              'Game Name',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter game name',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: const Color(0xFF143B69),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Player name field
            const Text(
              'Your Name',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _playerNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: const Color(0xFF143B69),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Max players slider
            const Text(
              'Max Players',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _maxPlayers.toDouble(),
                    min: 2,
                    max: 8,
                    divisions: 6,
                    label: _maxPlayers.toString(),
                    onChanged: (value) {
                      setState(() {
                        _maxPlayers = value.toInt();
                      });
                    },
                    activeColor: Colors.orange,
                    inactiveColor: const Color(0xFF143B69),
                  ),
                ),
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Text(
                    '$_maxPlayers',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Create button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _createLobby,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'CREATE LOBBY',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
