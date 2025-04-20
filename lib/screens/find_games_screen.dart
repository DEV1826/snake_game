import 'package:flutter/material.dart';
import '../networking/simple_network_manager.dart';
import '../models/game_lobby.dart';
import 'client_lobby_screen.dart';

class FindGamesScreen extends StatefulWidget {
  final String playerName;

  const FindGamesScreen({
    Key? key,
    this.playerName = "Player",
  }) : super(key: key);

  @override
  State<FindGamesScreen> createState() => _FindGamesScreenState();
}

class _FindGamesScreenState extends State<FindGamesScreen> {
  final SimpleNetworkManager _networkManager = SimpleNetworkManager(
    onGameStateUpdate: (_) {},
    onErrorMessage: (message) => print('Error: $message'),
  );
  
  List<GameLobby> _availableGames = [];
  bool _isSearching = false;
  bool _isConnecting = false;
  String? _errorMessage;
  
  // Add controllers for manual IP input
  final TextEditingController _ipController = TextEditingController(text: "192.168.1.");
  final TextEditingController _portController = TextEditingController(text: "35555");
  bool _showManualInput = false;
  
  @override
  void initState() {
    super.initState();
    _refreshGames();
  }
  
  void _refreshGames() {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _availableGames = [];
    });
    
    // Initialize network manager if not already done
    _networkManager.initialize().then((_) {
      // Start actual discovery process
      _networkManager.discoverGames().then((discoveredGames) {
        setState(() {
          _isSearching = false;
          _availableGames = discoveredGames;
          
          if (_availableGames.isEmpty) {
            _errorMessage = "No games found on your network. Make sure hosts are online and try again.";
          }
        });
      }).catchError((error) {
        setState(() {
          _isSearching = false;
          _errorMessage = "Error discovering games: $error";
        });
      });
    }).catchError((error) {
      setState(() {
        _isSearching = false;
        _errorMessage = "Network error: $error";
      });
    });
  }

  void _joinGame(GameLobby game) async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );
    
    try {
      // Initialize network manager if needed
      await _networkManager.initialize();
      
      final success = await _networkManager.joinGame(
        game.hostIp, 
        game.port,
        playerName: widget.playerName,
      );
      
      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (success && mounted) {
        // Navigate to client lobby screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientLobbyScreen(
              networkManager: _networkManager,
              playerName: widget.playerName,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = "Failed to join the game. Please try again.";
          _isConnecting = false;
        });
      }
    } catch (e) {
      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      setState(() {
        _errorMessage = "Error connecting: $e";
        _isConnecting = false;
      });
    }
  }

  void _joinManualGame() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );
    
    try {
      // Initialize network manager if needed
      await _networkManager.initialize();
      
      final ip = _ipController.text;
      final port = int.parse(_portController.text);
      
      final success = await _networkManager.joinGame(
        ip, 
        port,
        playerName: widget.playerName,
      );
      
      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (success && mounted) {
        // Navigate to client lobby screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientLobbyScreen(
              networkManager: _networkManager,
              playerName: widget.playerName,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = "Failed to join the game. Please try again.";
          _isConnecting = false;
        });
      }
    } catch (e) {
      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      setState(() {
        _errorMessage = "Error connecting: $e";
        _isConnecting = false;
      });
    }
  }

  @override
  void dispose() {
    _networkManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Available Games'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Info section
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(
              'Finding Games on Local Network...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ),
          
          // Available games list
          Expanded(
            child: _isSearching && _availableGames.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.orange),
                        SizedBox(height: 16),
                        Text(
                          'Searching for games...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  )
                : _availableGames.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.orange,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No games found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _availableGames.length,
                        itemBuilder: (context, index) {
                          final game = _availableGames[index];
                          return _buildGameCard(game);
                        },
                      ),
          ),
          
          // Error message if any
          if (_errorMessage != null) ...[  
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Manual IP input
          if (_showManualInput) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF143B69),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MANUAL CONNECTION',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange, width: 2),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white), // Make text visible
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange, width: 2),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white), // Make text visible
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _joinManualGame,
                      child: const Text('JOIN GAME'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Refresh button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isConnecting ? null : _refreshGames,
                icon: _isConnecting 
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(
                          color: Colors.white, 
                          strokeWidth: 2,
                        )
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _isConnecting ? 'CONNECTING...' : 'REFRESH',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          
          // Toggle manual IP input
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showManualInput = !_showManualInput;
                  });
                },
                child: Text(
                  _showManualInput ? 'HIDE MANUAL INPUT' : 'SHOW MANUAL INPUT',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          
          // Back button
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text(
                  'BACK TO MENU',
                  style: TextStyle(fontSize: 16),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(GameLobby game) {
    final playerCount = '${game.players.length}/${game.maxPlayers}';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: const Color(0xFF143B69),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        title: Text(
          game.hostName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Host: ${game.hostIp} • Players: $playerCount',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => _joinGame(game),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('JOIN'),
        ),
      ),
    );
  }
}
