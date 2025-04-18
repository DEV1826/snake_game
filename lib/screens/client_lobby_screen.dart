import 'package:flutter/material.dart';
import '../networking/simple_network_manager.dart';
import '../models/game_lobby.dart';
import 'game_screen.dart';

class ClientLobbyScreen extends StatefulWidget {
  final SimpleNetworkManager networkManager;
  final String playerName;

  const ClientLobbyScreen({
    Key? key,
    required this.networkManager,
    required this.playerName,
  }) : super(key: key);

  @override
  State<ClientLobbyScreen> createState() => _ClientLobbyScreenState();
}

class _ClientLobbyScreenState extends State<ClientLobbyScreen> {
  GameLobby? _lobby;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    
    // Listen for lobby updates from the network manager
    widget.networkManager.lobbyUpdates.listen((updatedLobby) {
      if (mounted) {
        setState(() {
          _lobby = updatedLobby;
        });
      }
    });
    
    // Listen for game start event
    widget.networkManager.onGameStarted = _onGameStarted;
    
    // Initialize with current lobby state
    setState(() {
      _lobby = widget.networkManager.lobby;
    });
  }
  
  void _onGameStarted() {
    // Navigate to the game screen when the host starts the game
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          isHost: false,
          hostIp: _lobby?.hostIp,
          port: _lobby?.port ?? 35555,
        ),
      ),
    );
  }

  void _toggleReadyStatus() {
    setState(() {
      _isReady = !_isReady;
    });
    
    // Send ready status to host
    widget.networkManager.sendReadyStatus(_isReady);
  }

  void _leaveGame() {
    // Leave the game
    widget.networkManager.disconnect();
    
    // Navigate back to the previous screen
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Game Lobby'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Host info
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF143B69),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _lobby == null
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : Row(
                    children: [
                      const Icon(Icons.person, color: Colors.orange, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Host: ${_lobby!.hostName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'IP: ${_lobby!.hostIp}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          
          // Player list
          Expanded(
            child: _lobby == null
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : ListView.builder(
                    itemCount: _lobby!.players.length,
                    itemBuilder: (context, index) {
                      final player = _lobby!.players[index];
                      return _buildPlayerCard(player);
                    },
                  ),
          ),
          
          // Ready and leave buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Ready button
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _toggleReadyStatus,
                      icon: Icon(_isReady ? Icons.cancel_outlined : Icons.check_circle_outline),
                      label: Text(_isReady ? 'NOT READY' : 'READY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isReady ? Colors.grey : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Leave game button
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _leaveGame,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('LEAVE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
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
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Player player) {
    // Check if this is the current player
    final isCurrentPlayer = player.id == widget.networkManager.playerId;
    
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
          backgroundColor: isCurrentPlayer ? Colors.blue : Colors.orange,
          child: Text('${player.id}'),
        ),
        title: Row(
          children: [
            Text(
              player.name,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            if (isCurrentPlayer)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'YOU',
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
