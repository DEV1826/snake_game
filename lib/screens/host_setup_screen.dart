import 'package:flutter/material.dart';
import '../networking/simple_network_manager.dart';
import 'game_screen.dart';

class HostSetupScreen extends StatefulWidget {
  const HostSetupScreen({Key? key}) : super(key: key);

  @override
  State<HostSetupScreen> createState() => _HostSetupScreenState();
}

class _HostSetupScreenState extends State<HostSetupScreen> {
  final TextEditingController _lobbyNameController = TextEditingController(text: 'Snake Game Lobby');
  final TextEditingController _playerNameController = TextEditingController(text: 'Host');
  int _maxPlayers = 4;
  String? _localIp;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getLocalIp();
  }

  Future<void> _getLocalIp() async {
    final networkManager = SimpleNetworkManager(onGameStateUpdate: (_) {});
    await networkManager.initialize();
    setState(() {
      _localIp = networkManager.localIp;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _lobbyNameController.dispose();
    _playerNameController.dispose();
    super.dispose();
  }

  void _createLobby() {
    if (_lobbyNameController.text.isEmpty || _playerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate to the lobby screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _HostLobbyPlaceholder(
          lobbyName: _lobbyNameController.text,
          playerName: _playerNameController.text,
          maxPlayers: _maxPlayers,
          localIp: _localIp ?? 'Unknown',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Host a Game'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Local IP address display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your IP Address: ${_localIp ?? "Unknown"}\n'
                        'Share this with players who want to join your game.',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Lobby name field
              const Text(
                'Lobby Name',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lobbyNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter lobby name',
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

              // Host name field
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
              Row(
                children: [
                  const Text(
                    'Max Players',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_maxPlayers',
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
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
              const SizedBox(height: 30),

              // Create lobby button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'CREATE LOBBY',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _createLobby,
                ),
              ),
            ],
          ),
        ),
    );
  }
}

// Placeholder for the host lobby (in a real app, this would be a full lobby screen)
class _HostLobbyPlaceholder extends StatelessWidget {
  final String lobbyName;
  final String playerName;
  final int maxPlayers;
  final String localIp;

  const _HostLobbyPlaceholder({
    Key? key,
    required this.lobbyName,
    required this.playerName,
    required this.maxPlayers,
    required this.localIp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: Text('Lobby: $lobbyName'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Host info card
            Card(
              margin: const EdgeInsets.all(16),
              color: const Color(0xFF143B69),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.green, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.orange,
                      radius: 30,
                      child: Icon(Icons.person, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      playerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'HOST • Ready',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'IP: $localIp',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                    Text(
                      'Max Players: $maxPlayers',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Waiting message
            const Text(
              'Waiting for players to join...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            
            const SizedBox(height: 32),
            
            // Start game button
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'START GAME',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => const GameScreen(isHost: true, port: 8080),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Cancel button
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel),
                label: const Text(
                  'CANCEL',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
