import 'package:flutter/material.dart';
import '../networking/simple_network_manager.dart';
import '../models/game_lobby.dart';
import 'game_screen.dart';

class HostLobbyScreen extends StatefulWidget {
  final SimpleNetworkManager networkManager;
  final String playerName;

  const HostLobbyScreen({
    Key? key,
    required this.networkManager,
    required this.playerName,
  }) : super(key: key);

  @override
  State<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends State<HostLobbyScreen> {
  GameLobby? _lobby;

  @override
  void initState() {
    super.initState();
    _initializeHost();
  }

  Future<void> _initializeHost() async {
    // Host a game with the given lobby name
    final success = await widget.networkManager.hostGame(
      35555, // Use a higher port that works better on real devices
      hostName: widget.playerName,
      maxPlayers: 4,
    );

    if (!success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to host game. Please check your network connection.'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
      return;
    }

    // Listen for lobby updates from the network manager
    widget.networkManager.lobbyUpdates.listen((updatedLobby) {
      if (mounted) {
        setState(() {
          _lobby = updatedLobby;
        });
      }
    });

    // Initialize with current lobby state
    setState(() {
      _lobby = widget.networkManager.lobby;
    });
  }

  void _startGame() {
    // Make sure we have a lobby
    if (_lobby == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lobby not initialized yet. Please wait.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Make sure we have at least one player besides the host
    if (_lobby!.players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one other player must join before starting.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Check if all connected players are ready
    final nonHostPlayers = _lobby!.players.where((player) => player.id != 0).toList();
    final allPlayersReady = nonHostPlayers.every((player) => player.isReady);
    
    if (!allPlayersReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not all players are ready!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Start the game
    widget.networkManager.startGame();
    
    // Navigate to the game screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          isHost: true,
          port: widget.networkManager.lobby.port,
          playerName: widget.playerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: Text('Game Lobby: ${widget.playerName}'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Player cards
          Expanded(
            child: _lobby == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _lobby!.players.length,
                    itemBuilder: (context, index) {
                      final player = _lobby!.players[index];
                      return _buildPlayerCard(player);
                    },
                  ),
          ),
          // Status indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF143B69),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getStatusMessage(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          
          // Start button (only for host)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow),
                label: const Text('START GAME'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get the appropriate status icon
  IconData _getStatusIcon() {
    if (_lobby == null) {
      return Icons.sync_problem;
    }
    
    // If no players besides host, show waiting icon
    if (_lobby!.players.length <= 1) {
      return Icons.people_outline;
    }
    
    // Check if all non-host players are ready
    final nonHostPlayers = _lobby!.players.where((player) => player.id != 0).toList();
    final allPlayersReady = nonHostPlayers.every((player) => player.isReady);
    
    return allPlayersReady ? Icons.check_circle : Icons.warning;
  }
  
  // Helper method to get the appropriate status color
  Color _getStatusColor() {
    if (_lobby == null) {
      return Colors.red;
    }
    
    // If no players besides host, show blue
    if (_lobby!.players.length <= 1) {
      return Colors.blue;
    }
    
    // Check if all non-host players are ready
    final nonHostPlayers = _lobby!.players.where((player) => player.id != 0).toList();
    final allPlayersReady = nonHostPlayers.every((player) => player.isReady);
    
    return allPlayersReady ? Colors.green : Colors.orange;
  }
  
  // Helper method to get the appropriate status message
  String _getStatusMessage() {
    if (_lobby == null) {
      return 'Initializing lobby...';
    } else if (_lobby!.players.length <= 1) {
      return 'Waiting for players to join...';
    } else {
      final nonHostPlayers = _lobby!.players.where((player) => player.id != 0).toList();
      final readyCount = nonHostPlayers.where((p) => p.isReady).length;
      final totalCount = nonHostPlayers.length;
      return '$readyCount of $totalCount players are ready...';
    }
  }
  
  @override
  void dispose() {
    print('HostLobbyScreen being disposed');
    
    // If navigating away without starting the game, we need to clean up network resources
    // This ensures server socket and all listening ports are closed
    if (!widget.networkManager.isGameRunning) {
      print('Game not started, cleaning up network resources');
      widget.networkManager.dispose();
    }
    
    super.dispose();
  }
  
  Widget _buildPlayerCard(Player player) {
    final isHost = player.id == 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: const Color(0xFF143B69),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: player.isReady ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isHost ? Colors.purple : Colors.orange,
          child: Text('${player.id}'),
        ),
        title: Row(
          children: [
            Text(
              player.name,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            if (isHost)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'HOST',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        subtitle: Text(
          player.ipAddress,
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        trailing: player.isReady
            ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
            : const Icon(Icons.hourglass_empty, color: Colors.orange, size: 28),
      ),
    );
  }
}
