import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../models/game_lobby.dart';
import '../models/game_state.dart';
import '../utils/socket_cleanup.dart';

/// A simplified network manager that works reliably for Snake multiplayer
class SimpleNetworkManager {
  // Constants
  static const int defaultPort = 35555; // Using a much higher port number that works better on real devices
  static const int discoveryPort = 35556;
  
  // Server socket (for host)
  ServerSocket? _server;
  
  // Client socket (for client)
  Socket? _client;
  
  // Connection callback
  Function(bool)? onConnectionStatusChanged;
  
  // Error message callback
  Function(String)? onErrorMessage;
  
  // Game state update callback
  final Function(GameState) onGameStateUpdate;
  
  // Game started callback
  Function()? onGameStarted;
  
  // Network properties
  String? _localIp;
  int _playerId = 0;
  
  // Game state
  GameState _gameState = GameState();
  
  // Hosting
  List<Socket> _connectedClients = [];
  Timer? _broadcastTimer;
  Timer? _heartbeatTimer;
  
  // Player tracking
  final Map<int, String> _playerNames = {}; // Map of player IDs to names
  
  // Lobby management
  GameLobby _lobby = GameLobby(
    hostName: 'Unknown',
    hostIp: 'Unknown',
    port: defaultPort,
    maxPlayers: 4,
  );
  final List<Player> _players = [];
  final _lobbyUpdateController = StreamController<GameLobby>.broadcast();
  
  SimpleNetworkManager({
    required this.onGameStateUpdate,
    this.onErrorMessage,
    this.onConnectionStatusChanged,
    this.onGameStarted,
  });
  
  // Initialize and get local IP
  Future<void> initialize() async {
    try {
      // Try multiple methods to get the WiFi IP address
      // Method 1: Use network_info_plus plugin
      final info = NetworkInfo();
      _localIp = await info.getWifiIP();
      print('NetworkInfo WiFi IP: $_localIp');
      
      // Check if we got a valid IP
      if (_localIp == null || _localIp!.isEmpty || _localIp == '127.0.0.1') {
        // Method 2: Connect to a public server and get our address
        try {
          print('Trying method 2: Socket connection to public DNS');
          final socket = await Socket.connect('8.8.8.8', 53); // Google DNS
          _localIp = socket.address.address;
          await socket.close();
          print('Got IP from socket connection: $_localIp');
        } catch (socketError) {
          print('Error getting IP from socket: $socketError');
          
          // Method 3: Try to get the list of all network interfaces
          try {
            print('Trying method 3: Network interfaces');
            final interfaces = await NetworkInterface.list(
              includeLinkLocal: false,
              includeLoopback: false,
              type: InternetAddressType.IPv4,
            );
            
            // Find a suitable IP address (non-loopback)
            for (var interface in interfaces) {
              print('Network interface: ${interface.name}');
              for (var addr in interface.addresses) {
                final ip = addr.address;
                print('Address on ${interface.name}: $ip');
                if (!ip.startsWith('127.') && !ip.startsWith('169.')) {
                  _localIp = ip;
                  print('Selected IP from interfaces: $_localIp');
                  break;
                }
              }
              if (_localIp != null && _localIp != '127.0.0.1') break;
            }
          } catch (ifaceError) {
            print('Error getting network interfaces: $ifaceError');
          }
        }
      }
      
      // If we still couldn't get a valid IP, fallback to localhost
      if (_localIp == null || _localIp!.isEmpty) {
        _localIp = '127.0.0.1';
        print('Falling back to localhost: $_localIp');
      }
      
      print('Final selected IP: $_localIp');
    } catch (e) {
      print('Error initializing network: $e');
      _localIp = '127.0.0.1';
    }
  }
  
  // Host a game with lobby
  Future<bool> hostGame(int port, {required String hostName, int maxPlayers = 4}) async {
    if (_localIp == null) {
      await initialize();
    }
    
    try {
      print('Cleaning up any existing resources before hosting');
      // Ensure any previous resources are fully cleaned up
      await _cleanupHostResources();
      
      // Wait a short time to ensure port is fully released
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Try different approaches to create a server socket
      bool bindSuccess = false;
      
      // Check if port is already in use by attempting to bind
      bool isPortAvailable = false;
      try {
        final testSocket = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          port,
          shared: true,
        ).timeout(const Duration(milliseconds: 300));
        
        // If we get here, the port is available
        isPortAvailable = true;
        testSocket.close();
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        print('Port $port is already in use or blocked: $e');
        isPortAvailable = false;
      }
      
      // First attempt: Try binding to the specific local IP address with the original port
      if (!bindSuccess && isPortAvailable && _localIp != null && _localIp != '127.0.0.1') {
        try {
          _server = await ServerSocket.bind(
            InternetAddress(_localIp!),
            port,
            shared: true,
          );
          
          print('Successfully bound to specific IP: $_localIp on port $port');
          bindSuccess = true;
        } catch (e) {
          print('Failed to bind to specific IP: $e');
        }
      }
      
      // Second attempt: Try with a different port far from the default range
      if (!bindSuccess) {
        try {
          // Try a random port in a high range to avoid conflicts
          final randomPort = 50000 + Random().nextInt(10000);
          
          // Check if the random port is available
          bool isRandomPortAvailable = false;
          try {
            final testSocket = await ServerSocket.bind(
              InternetAddress.anyIPv4,
              randomPort,
              shared: true,
            ).timeout(const Duration(milliseconds: 300));
            
            isRandomPortAvailable = true;
            testSocket.close();
            await Future.delayed(const Duration(milliseconds: 200));
          } catch (e) {
            print('Random port $randomPort is already in use: $e');
            isRandomPortAvailable = false;
          }
          
          if (isRandomPortAvailable) {
            _server = await ServerSocket.bind(
              InternetAddress.anyIPv4, 
              randomPort,
              shared: true,
            );
            
            // Update the port number to the new one
            port = randomPort; 
            print('Successfully bound to alternate port $port');
            bindSuccess = true;
          }
        } catch (e) {
          print('Failed to bind to alternate port: $e');
        }
      }
      
      if (!bindSuccess) {
        print('Failed to bind to any address');
        onErrorMessage?.call('Failed to create game server. All ports in use or network error.');
        return false;
      }
      
      // Register server socket for cleanup
      if (_server != null) {
        SocketCleanup.registerServerSocket(_server!);
        print('Socket on port $port registered for cleanup');
      }
      
      print('Hosting game on $_localIp:$port');
      
      // Initialize game lobby
      _lobby = GameLobby(
        hostName: hostName,
        hostIp: _localIp!,
        port: port,
        maxPlayers: maxPlayers,
      );
      
      // Add host as first player
      final Player hostPlayer = Player(
        id: 0, // Host is always player 0
        name: hostName,
        ipAddress: _localIp!,
        isReady: true, // Host is always ready
      );
      
      _players.add(hostPlayer);
      _lobby.players.add(hostPlayer);
      
      // Add host to player names map
      _playerNames[0] = hostName;
      
      // Set up initial game state
      _gameState = GameState();
      _playerId = 0;
      _gameState.spawnSnake(_playerId);
      _gameState.spawnFood();
      
      // Set up server for clients to connect
      _setupServer(port);
      
      // Start broadcasting game presence for discovery
      _startBroadcastingPresence();
      
      return true;
    } catch (e) {
      print('Error hosting game: $e');
      onErrorMessage?.call('Failed to host game: $e');
      return false;
    }
  }
  
  // Set up server for clients to connect
  void _setupServer(int port) async {
    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      
      // Register server socket for cleanup
      SocketCleanup.registerServerSocket(_server!);
      
      print('Server started on port $port');
      _server?.listen(
        (Socket client) {
          print('Client connected: ${client.remoteAddress.address}');
          
          // Configure socket for more stability
          try {
            client.setOption(SocketOption.tcpNoDelay, true);  // Disable Nagle's algorithm
          } catch (e) {
            print('Error configuring socket: $e');
          }
          
          // Register client socket for cleanup
          SocketCleanup.registerClientSocket(client);
          
          // Add client to connected clients list
          _connectedClients.add(client);
          
          // Listen for client messages
          client.listen(
            (data) => _handleClientMessage(data, client),
            onError: (error) {
              print('Client error: $error');
              _handleClientDisconnect(client);
            },
            onDone: () {
              print('Client disconnected');
              _handleClientDisconnect(client);
            },
          );
        },
        onError: (error) {
          print('Server error: $error');
          onErrorMessage?.call('Server error: $error');
        },
        onDone: () {
          print('Server socket closed');
        },
      );
      
      // Start heartbeat to keep connections alive
      _startHeartbeat();
      
    } catch (e) {
      print('Error starting server: $e');
      onErrorMessage?.call('Failed to start game server: $e');
    }
  }
  
  // Start sending heartbeats to keep clients connected
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_connectedClients.isEmpty) return;
      
      // Send lightweight heartbeat to all clients
      final heartbeat = {'type': 'heartbeat', 'timestamp': DateTime.now().millisecondsSinceEpoch};
      _broadcastToClients(heartbeat);
      
      print('Sent heartbeat to ${_connectedClients.length} clients');
    });
  }
  
  // Start broadcasting game presence for discovery
  void _startBroadcastingPresence() {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      try {
        // Create a broadcast socket
        RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
          // Create discovery message
          final discoveryMessage = jsonEncode({
            'type': 'game_discovery',
            'hostName': _lobby.hostName,
            'hostIp': _localIp,
            'port': _lobby.port,
            'players': _lobby.players.length,
            'maxPlayers': _lobby.maxPlayers,
            'timestamp': DateTime.now().millisecondsSinceEpoch, // Add timestamp for uniqueness
          });
          
          // Convert to bytes
          final data = utf8.encode(discoveryMessage);
          
          // Enable broadcast on socket
          socket.broadcastEnabled = true;
          
          // Send to primary broadcast address
          socket.send(data, InternetAddress('255.255.255.255'), discoveryPort);
          
          // Also try sending to some common subnet broadcast addresses
          for (final subnet in ['192.168.0.255', '192.168.1.255', '192.168.2.255', '10.0.0.255', '10.0.1.255']) {
            try {
              socket.send(data, InternetAddress(subnet), discoveryPort);
            } catch (e) {
              // Ignore errors for individual subnet attempts
            }
          }
          
          // Clean up
          socket.close();
        });
      } catch (e) {
        print('Error broadcasting game presence: $e');
      }
    });
  }
  
  // Handle client message (as host)
  void _handleClientMessage(List<int> data, Socket client) {
    try {
      final String message = utf8.decode(data);
      final Map<String, dynamic> decoded = jsonDecode(message);
      
      print('Received message: $decoded');
      
      switch (decoded['type']) {
        case 'heartbeat':
          // Client is checking if we're still alive
          _sendToClient(client, {'type': 'heartbeat_ack'});
          break;
          
        case 'heartbeat_ack':
          // Client acknowledged our heartbeat, do nothing
          break;
          
        case 'join_request':
          final String playerName = decoded['name'] ?? 'Unknown';
          final int requestId = decoded['requestId'] ?? 0;
          final String clientVersion = decoded['clientVersion'] ?? '1.0';
          
          print('Processing join request from $playerName (request ID: $requestId, version: $clientVersion)');
          
          // Generate a player ID for the new client
          final int newPlayerId = _players.length;
          
          // Accept the player
          final Player newPlayer = Player(
            id: newPlayerId,
            name: playerName,
            ipAddress: client.remoteAddress.address,
            isReady: false,
          );
          
          _players.add(newPlayer);
          _lobby.players.add(newPlayer);
          
          // Add player to player names map
          _playerNames[newPlayerId] = playerName;
          
          // Notify other clients about the new player
          _broadcastToClients({
            'type': 'player_joined',
            'player': newPlayer.toJson(),
          }, exceptClient: client);
          
          // Create player name map with string keys for serialization
          final Map<String, String> serializedPlayerNames = {};
          _playerNames.forEach((id, name) {
            serializedPlayerNames[id.toString()] = name;
          });
          
          // Send acceptance to the new client
          _sendToClient(client, {
            'type': 'join_accepted',
            'playerId': newPlayerId,
            'requestId': requestId,
            'lobby': _lobby.toJson(),
            'playerNames': serializedPlayerNames,
          });
          
          // Update game state with the new player's snake
          _gameState.spawnSnake(newPlayerId);
          
          // Broadcast updated game state
          _broadcastGameState();
          
          // Notify UI listeners
          _lobbyUpdateController.add(_lobby);
          break;
          
        case 'join_confirmation':
          // Client confirmed successful join
          final int playerId = decoded['playerId'] ?? -1;
          print('Received join confirmation from player $playerId');
          
          // Find the player in our list
          final playerIndex = _players.indexWhere((p) => p.id == playerId);
          if (playerIndex >= 0) {
            print('Player $playerId confirmed connection');
          }
          break;
          
        case 'player_ready':
          final int clientId = decoded['playerId'] ?? -1;
          if (clientId >= 0 && clientId < _players.length) {
            _players[clientId].isReady = true;
            _lobby.players[clientId].isReady = true;
            
            // Broadcast player ready status to all clients
            _broadcastToClients({
              'type': 'player_status_update',
              'playerId': clientId,
              'isReady': true,
            });
            
            // Notify UI listeners
            _lobbyUpdateController.add(_lobby);
            
            // Check if all players are ready to start the game
            if (_players.every((p) => p.isReady)) {
              _startGame();
            }
          }
          break;
          
        case 'player_move':
          final int clientId = decoded['playerId'] ?? -1;
          final String direction = decoded['direction'] ?? 'right';
          
          if (clientId >= 0 && clientId < _gameState.snakes.length) {
            // Find the snake with matching ID
            final snakes = _gameState.snakes.where((s) => s.id == clientId);
            if (snakes.isNotEmpty) {
              // Update direction
              snakes.first.direction = direction;
              
              // Broadcast the move to all clients
              _broadcastToClients({
                'type': 'player_move',
                'playerId': clientId,
                'direction': direction,
              }, exceptClient: client);
            }
          }
          break;
          
        case 'chat_message':
          final int senderId = decoded['playerId'] ?? -1;
          final String message = decoded['message'] ?? '';
          
          if (senderId >= 0 && senderId < _players.length && message.isNotEmpty) {
            // Broadcast chat message to all clients
            _broadcastToClients({
              'type': 'chat_message',
              'playerId': senderId,
              'playerName': _players[senderId].name,
              'message': message,
            });
          }
          break;
      }
    } catch (e) {
      print('Error parsing client message: $e');
    }
  }
  
  // Handle client disconnection
  void _handleClientDisconnect(Socket client) {
    // Find the client in the connected clients list
    final index = _connectedClients.indexOf(client);
    if (index < 0) return; // Client not found
    
    // Get the client's IP address for logging
    final clientIp = client.remoteAddress.address;
    print('Client disconnected: $clientIp');
    
    // Remove client from connected clients list
    _connectedClients.remove(client);
    
    // Find the player associated with this client
    // We need to look through all players as the index might not match player ID
    Player? disconnectedPlayer;
    for (var player in _players) {
      if (player.ipAddress == clientIp) {
        disconnectedPlayer = player;
        break;
      }
    }
    
    if (disconnectedPlayer != null) {
      final playerId = disconnectedPlayer.id;
      
      // Remove player from lobby
      _lobby.players.removeWhere((p) => p.id == playerId);
      _players.removeWhere((p) => p.id == playerId);
      
      // Remove snake from game state if it exists
      _gameState.snakes.removeWhere((s) => s.id == playerId);
      
      // Broadcast player disconnection to remaining clients
      _broadcastToClients({
        'type': 'player_disconnected',
        'playerId': playerId,
      });
      
      // Broadcast updated game state
      _broadcastGameState();
      
      // Update lobby subscribers
      _lobbyUpdateController.add(_lobby);
    }
    
    try {
      // Close the client socket if it's still open
      client.destroy();
    } catch (e) {
      print('Error closing client socket: $e');
    }
  }
  
  // Broadcast game state to all clients
  void _broadcastGameState() {
    // Convert snake positions to serializable format
    final snakesData = _gameState.snakes.map((snake) {
      final positionsData = snake.positions.map((pos) => {
        'x': pos.dx,
        'y': pos.dy,
      }).toList();
      
      return {
        'id': snake.id,
        'positions': positionsData,
        'direction': snake.direction,
        'length': snake.positions.length,
        'isDead': snake.isDead,
        'score': snake.score,
      };
    }).toList();
    
    // Convert food positions to serializable format
    final foodsData = _gameState.foods.map((food) => {
      'x': food.position.dx,
      'y': food.position.dy,
    }).toList();
    
    // Prepare state packet
    final statePacket = {
      'type': 'game_state',
      'state': {
        'snakes': snakesData,
        'foods': foodsData,
      },
    };
    
    // Broadcast to all clients
    _broadcastToClients(statePacket);
  }
  
  // Broadcast message to all connected clients
  void _broadcastToClients(Map<String, dynamic> message, {Socket? exceptClient}) {
    final String encoded = jsonEncode(message);
    final List<int> data = utf8.encode(encoded);
    
    for (var client in _connectedClients) {
      if (exceptClient != client) {
        try {
          client.add(data);
        } catch (e) {
          print('Error sending to client: $e');
        }
      }
    }
  }
  
  // Start the game (as host)
  void _startGame() {
    _broadcastToClients({
      'type': 'game_start',
    });
    
    onGameStarted?.call();
  }
  
  // Public method to start the game (called from host UI)
  void startGame() {
    if (_server == null) return; // Not hosting
    
    // Ensure all players are ready
    if (!_lobby.players.every((p) => p.isReady)) {
      onErrorMessage?.call('Not all players are ready');
      return;
    }
    
    // Reset game state
    _gameState = GameState();
    
    // Spawn snakes for all players
    for (int i = 0; i < _lobby.players.length; i++) {
      _gameState.spawnSnake(i);
    }
    
    // Spawn initial food
    _gameState.spawnFood(cols: GameState.gridWidth, rows: GameState.gridHeight);
    
    // Start the game
    _startGame();
  }
  
  // Join a hosted game
  Future<bool> joinGame(String hostIp, int port, {required String playerName}) async {
    print('Attempting to join game at $hostIp:$port as $playerName');
    try {
      // Close any existing connections
      disconnect();
      
      // Reset connection state
      _playerId = -1;
      
      // Create a connection to the host
      _client = await Socket.connect(
        hostIp, 
        port,
        timeout: const Duration(seconds: 10),
      );
      
      // Register client socket for cleanup
      SocketCleanup.registerClientSocket(_client!);
      
      print('Connected to host at $hostIp:$port');
      
      // Configure socket for stability
      try {
        _client?.setOption(SocketOption.tcpNoDelay, true);  // Disable Nagle's algorithm
      } catch (e) {
        print('Error configuring client socket: $e');
      }
      
      // Setup heartbeat timer to keep connection alive
      _setupClientHeartbeat();
      
      // Listen for messages from the host
      _client?.listen(
        (data) {
          try {
            final String message = utf8.decode(data);
            final Map<String, dynamic> decoded = jsonDecode(message);
            
            print('Received from host: $decoded');
            
            // Handle different message types
            switch (decoded['type']) {
              case 'heartbeat':
                // Respond to heartbeat to keep connection alive
                _sendToHost({'type': 'heartbeat_ack'});
                break;
                
              case 'heartbeat_ack':
                // Host acknowledged our heartbeat, do nothing
                break;
                
              case 'join_accepted':
                // Extract player ID
                _playerId = decoded['playerId'] ?? -1;
                
                // Update lobby info
                if (decoded.containsKey('lobby')) {
                  try {
                    _lobby = GameLobby.fromJson(decoded['lobby']);
                    _lobbyUpdateController.add(_lobby);
                  } catch (e) {
                    print('Error parsing lobby data: $e');
                  }
                }
                
                // Process player names if available
                if (decoded.containsKey('playerNames')) {
                  try {
                    final Map<String, dynamic> namesMap = decoded['playerNames'];
                    namesMap.forEach((key, value) {
                      try {
                        final id = int.parse(key);
                        _playerNames[id] = value.toString();
                      } catch (e) {
                        print('Error parsing player name ID: $e');
                      }
                    });
                    print('Processed player names: $_playerNames');
                  } catch (e) {
                    print('Error processing player names: $e');
                  }
                }
                
                // Send an acknowledgment to confirm join success
                try {
                  _sendToHost({
                    'type': 'join_confirmation',
                    'playerId': _playerId,
                  });
                  print('Sent join confirmation with ID: $_playerId');
                } catch (e) {
                  print('Error sending join confirmation: $e');
                }
                
                // Notify connection status change
                onConnectionStatusChanged?.call(true);
                
                break;
                
              case 'game_start':
                // Host started the game
                onGameStarted?.call();
                break;
                
              case 'game_state':
                // Handle game state update from server
                if (decoded.containsKey('state')) {
                  _updateGameStateFromServer(decoded['state']);
                }
                break;
            }
            
          } catch (e) {
            print('Error parsing server message: $e');
          }
        },
        onError: (error) {
          print('Socket error: $error');
          disconnect();
          if (onErrorMessage != null) {
            onErrorMessage!('Connection error: $error');
          }
        },
        onDone: () {
          print('Socket closed by server');
          disconnect();
          if (onErrorMessage != null) {
            onErrorMessage!('Disconnected from server');
          }
        },
      );
      
      // Generate a random request ID for tracking
      final requestId = Random().nextInt(10000);
      
      // Send join request with player name
      _sendToHost({
        'type': 'join_request',
        'name': playerName,
        'requestId': requestId,
        'clientVersion': '1.0', // Add version info for compatibility checking
      });
      
      // Return success - the response will be handled by the listener
      return true;
    } catch (e) {
      print('Error joining game: $e');
      if (onErrorMessage != null) {
        onErrorMessage!('Connection error: $e');
      }
      return false;
    }
  }
  
  // Update game state from server message
  void _updateGameStateFromServer(Map<String, dynamic> stateData) {
    // Update snakes
    if (stateData.containsKey('snakes')) {
      final List<dynamic> snakesList = stateData['snakes'];
      final List<Snake> snakes = [];
      
      for (var snakeData in snakesList) {
        final int id = snakeData['id'] ?? 0;
        final String direction = snakeData['direction'] ?? 'right';
        final int length = snakeData['length'] ?? 3;
        final bool isDead = snakeData['isDead'] ?? false;
        final int score = snakeData['score'] ?? 0;
        
        final List<Offset> positions = [];
        if (snakeData.containsKey('positions')) {
          final List<dynamic> positionsList = snakeData['positions'];
          for (var posData in positionsList) {
            positions.add(Offset(
              posData['x']?.toDouble() ?? 0,
              posData['y']?.toDouble() ?? 0,
            ));
          }
        }
        
        // Create snake with ID, positions, and direction
        snakes.add(Snake(id, positions, direction, length, 
          isDead: isDead, score: score));
      }
      
      // Update foods
      final List<Food> foods = [];
      if (stateData.containsKey('foods')) {
        final List<dynamic> foodsList = stateData['foods'];
        for (var foodData in foodsList) {
          foods.add(Food(Offset(
            foodData['x']?.toDouble() ?? 0,
            foodData['y']?.toDouble() ?? 0,
          )));
        }
      }
      
      // Create new game state
      final newState = GameState();
      newState.snakes = snakes;
      newState.foods = foods;
      
      // Update observer
      onGameStateUpdate(newState);
      
      // Save game state
      _gameState = newState;
    }
  }
  
  // Handle a game tick update (for host)
  void updateGameState(GameState updatedState) {
    // Update our local copy of the game state
    _gameState = updatedState;
    
    // Broadcast the updated state to all clients
    _broadcastGameState();
  }
  
  // Send current player's move to the host
  void sendMove(String direction) {
    if (_client != null) {
      _sendToHost({
        'type': 'player_move',
        'playerId': _playerId,
        'direction': direction,
      });
    }
  }
  
  // Send ready status to host (client only)
  void sendReadyStatus(bool isReady) {
    if (_client != null) {
      final message = {
        'type': 'player_ready',
        'playerId': _playerId,
        'isReady': isReady,
      };
      
      _sendToHost(message);
    }
  }
  
  // Client-specific disconnect method
  void disconnect() {
    print('Disconnecting from host');
    
    // Cancel client heartbeat
    _clientHeartbeatTimer?.cancel();
    _clientHeartbeatTimer = null;
    
    // Notify host about disconnection
    if (_client != null) {
      try {
        _sendToHost({
          'type': 'player_disconnect',
          'playerId': _playerId,
        });
      } catch (e) {
        print('Error notifying host about disconnect: $e');
      }
      
      // Unregister client socket from cleanup registry
      SocketCleanup.unregisterClientSocket(_client!);
    }
    
    // Close client socket
    _client?.destroy();
    _client = null;
    
    onConnectionStatusChanged?.call(false);
  }
  
  // Free all resources
  void dispose() {
    print('Disposing network manager');
    
    // Cancel all timers
    _broadcastTimer?.cancel();
    _heartbeatTimer?.cancel();
    _clientHeartbeatTimer?.cancel();
    
    // Close server socket if hosting
    if (_server != null) {
      try {
        // Close all client connections first
        for (var client in _connectedClients) {
          try {
            // Notify clients about server shutdown
            _sendToClient(client, {'type': 'server_shutdown'});
            
            // Unregister client socket
            SocketCleanup.unregisterClientSocket(client);
            
            client.destroy();
          } catch (e) {
            print('Error closing client connection: $e');
          }
        }
        
        // Unregister server socket
        SocketCleanup.unregisterServerSocket(_server!);
        
        _server?.close();
      } catch (e) {
        print('Error closing server: $e');
      }
      _server = null;
    }
    
    _connectedClients.clear();
    
    // Close client socket if connected
    if (_client != null) {
      try {
        print('Closing connection to host');
        
        // Unregister client socket
        SocketCleanup.unregisterClientSocket(_client!);
        
        _client?.destroy();
        _client = null;
      } catch (e) {
        print('Error closing client socket: $e');
      }
    }
    
    // Clean up stream controllers
    _lobbyUpdateController.close();
  }
  
  // Game state flag
  bool _isGameRunning = false;
  
  // Getters
  int get playerId => _playerId;
  bool get isHost => _server != null;
  String? get localIp => _localIp;
  GameLobby get lobby => _lobby;
  Stream<GameLobby> get lobbyUpdates => _lobbyUpdateController.stream;
  bool get isGameRunning => _isGameRunning;
  Map<int, String> get playerNames => _playerNames;
  
  // Helper: Send message to client
  void _sendToClient(Socket client, Map<String, dynamic> message) {
    try {
      // Convert message to JSON string
      final jsonString = json.encode(message);
      
      // Log for debugging
      print('Sending message type: ${message['type']} to ${client.remoteAddress.address}');
      
      // Send data
      client.write(jsonString);
      
      // Flush data to ensure it's sent immediately
      client.flush();
    } catch (e) {
      print('Error sending to client: $e');
      
      // Schedule a check to see if client is still connected
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          // Try a minimal heartbeat message
          client.write('{"type":"heartbeat"}');
        } catch (_) {
          // Client is truly disconnected, handle cleanup
          _handleClientDisconnect(client);
        }
      });
    }
  }
  
  // Helper: Send message to host
  void _sendToHost(Map<String, dynamic> message) {
    try {
      // Convert to JSON string
      final jsonString = json.encode(message);
      
      print('Sending to host: ${message['type']}');
      
      // Send and flush to ensure immediate delivery
      _client?.write(jsonString);
      _client?.flush();
    } catch (e) {
      print('Error sending to host: $e');
      
      // Only disconnect if it's a serious error
      if (e.toString().contains('Socket closed') || 
          e.toString().contains('Connection closed') ||
          e.toString().contains('not connected')) {
        disconnect();
      }
    }
  }
  
  // Discover available games on the local network
  Future<List<GameLobby>> discoverGames({int searchDurationSeconds = 3}) async {
    List<GameLobby> discoveredGames = [];
    
    if (_localIp == null) {
      await initialize();
    }
    
    if (_localIp == null) {
      throw Exception('Could not determine local IP address');
    }
    
    try {
      // Create socket for receiving broadcasts on all interfaces
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      
      // Create a completer to control the discovery duration
      final completer = Completer<List<GameLobby>>();
      
      // Handle incoming broadcast packets
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          try {
            // Read the packet
            final packet = socket.receive();
            if (packet == null) return;
            
            final data = utf8.decode(packet.data);
            
            // Parse the discovery message
            final message = jsonDecode(data);
            if (message['type'] == 'game_discovery') {
              final hostIp = message['hostIp'];
              final hostPort = message['port'];
              
              print('Discovered game: $hostIp:$hostPort with name ${message['hostName']}');
              
              // Create a game discovery object
              final game = GameLobby(
                hostName: message['hostName'] ?? 'Unknown Game',
                hostIp: hostIp,
                port: hostPort,
                currentPlayers: message['players'] ?? 1,
                maxPlayers: message['maxPlayers'] ?? 4,
              );
              
              // Check if we already have this game discovered
              final existingIndex = discoveredGames.indexWhere(
                (g) => g.hostIp == game.hostIp && g.port == game.port
              );
              
              // Add or update the game
              if (existingIndex >= 0) {
                discoveredGames[existingIndex] = game;
              } else {
                discoveredGames.add(game);
              }
              
              // Notify listeners
              // _discoveredGamesController.add(_discoveredGames);
            }
          } catch (e) {
            print('Error processing discovery packet: $e');
          }
        }
      },
      onError: (error) {
        print('Socket error during discovery: $error');
      },
      onDone: () {
        print('Discovery socket closed');
      });
      
      // Complete after given duration
      Future.delayed(Duration(seconds: searchDurationSeconds), () {
        if (!completer.isCompleted) {
          print('Discovery completed, found ${discoveredGames.length} games');
          socket.close();
          completer.complete(discoveredGames);
        }
      });
      
      return completer.future;
    } catch (e) {
      print('Error during game discovery: $e');
      return discoveredGames;
    }
  }
  
  // Setup client heartbeat timer
  Timer? _clientHeartbeatTimer;
  void _setupClientHeartbeat() {
    // Cancel any existing timer
    _clientHeartbeatTimer?.cancel();
    
    // Create new timer
    _clientHeartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_client != null) {
        try {
          _sendToHost({'type': 'heartbeat'});
        } catch (e) {
          print('Error sending heartbeat: $e');
          timer.cancel();
        }
      } else {
        // Client disconnected, stop timer
        timer.cancel();
      }
    });
  }
  
  // Clean up host resources
  Future<void> _cleanupHostResources() async {
    // Close server socket if hosting
    if (_server != null) {
      try {
        // Close all client connections first
        for (var client in _connectedClients) {
          try {
            // Notify clients about server shutdown
            _sendToClient(client, {'type': 'server_shutdown'});
            client.destroy();
          } catch (e) {
            print('Error closing client connection: $e');
          }
        }
        
        // Unregister server socket for cleanup
        SocketCleanup.unregisterServerSocket(_server!);
        
        _server?.close();
      } catch (e) {
        print('Error closing server: $e');
      }
      _server = null;
    }
    
    _connectedClients.clear();
  }
}
