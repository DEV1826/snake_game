import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/game_state.dart';
import '../models/game_lobby.dart';

/// A simplified network manager that works reliably for Snake multiplayer
class SimpleNetworkManager {
  // Constants
  static const int defaultPort = 35555; // Using a much higher port number that works better on real devices
  static const int discoveryPort = 35556;
  
  // Network properties
  String? _localIp;
  ServerSocket? _server;
  Socket? _client;
  int _playerId = 0;
  
  // Game state
  final Function(GameState) onGameStateUpdate;
  GameState _gameState = GameState();
  
  // Hosting
  List<Socket> _connectedClients = [];
  Timer? _broadcastTimer;
  
  // Lobby management
  GameLobby _lobby = GameLobby(
    hostName: 'Unknown',
    hostIp: 'Unknown',
    port: defaultPort,
    maxPlayers: 4,
  );
  final List<Player> _players = [];
  final _lobbyUpdateController = StreamController<GameLobby>.broadcast();
  
  // Callbacks
  Function(String)? onErrorMessage;
  Function(bool)? onConnectionStatusChanged;
  Function()? onGameStarted;
  
  SimpleNetworkManager({
    required this.onGameStateUpdate,
    this.onErrorMessage,
    this.onConnectionStatusChanged,
    this.onGameStarted,
  });
  
  // Initialize and get local IP
  Future<void> initialize() async {
    try {
      // Try to get the WiFi IP address
      final info = NetworkInfo();
      _localIp = await info.getWifiIP();
      print('Local IP: $_localIp');
      
      // If we couldn't get a valid IP, try alternative methods
      if (_localIp == null || _localIp!.isEmpty || _localIp == '127.0.0.1') {
        // Try to get the IP by creating a temporary socket
        try {
          final socket = await Socket.connect('8.8.8.8', 53); // Google DNS
          _localIp = socket.address.address;
          await socket.close();
          print('Got IP from socket: $_localIp');
        } catch (socketError) {
          print('Error getting IP from socket: $socketError');
          _localIp = '127.0.0.1'; // Fallback to localhost
        }
      }
    } catch (e) {
      print('Error getting IP: $e');
      _localIp = '127.0.0.1';
    }
  }
  
  // Host a game with lobby
  Future<bool> hostGame(int port, {required String hostName, int maxPlayers = 4}) async {
    if (_localIp == null) {
      await initialize();
    }
    
    try {
      // Try different approaches to create a server socket
      bool bindSuccess = false;
      
      // First attempt: Try binding to the specific local IP address
      if (!bindSuccess && _localIp != null && _localIp != '127.0.0.1') {
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
      
      // Second attempt: Try binding to anyIPv4
      if (!bindSuccess) {
        try {
          _server = await ServerSocket.bind(
            InternetAddress.anyIPv4,
            port,
            shared: true,
          );
          print('Successfully bound to anyIPv4 on port $port');
          bindSuccess = true;
        } catch (e) {
          print('Failed to bind to anyIPv4: $e');
        }
      }
      
      // Third attempt: Try binding to loopback address
      if (!bindSuccess) {
        try {
          _server = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            port,
            shared: true,
          );
          print('Successfully bound to loopback on port $port');
          bindSuccess = true;
        } catch (e) {
          print('Failed to bind to loopback: $e');
        }
      }
      
      // Fourth attempt: Try with a different port
      if (!bindSuccess) {
        try {
          _server = await ServerSocket.bind(
            InternetAddress.anyIPv4,
            port + 1,
            shared: true,
          );
          print('Successfully bound to anyIPv4 on alternate port ${port + 1}');
          // Update the port
          port = port + 1;
          bindSuccess = true;
        } catch (e) {
          print('Failed to bind to alternate port: $e');
        }
      }
      
      // If all binding attempts failed, throw an exception
      if (!bindSuccess) {
        throw Exception('Failed to bind to any socket configuration');
      }
      
      print('Hosting game on $_localIp:$port');
      
      // Set up lobby
      _lobby = GameLobby(
        hostName: hostName,
        hostIp: _localIp ?? 'Unknown',
        port: port,
        maxPlayers: maxPlayers,
      );
      
      // Add host as a player
      final hostPlayer = Player(
        id: 0,
        name: hostName,
        ipAddress: _localIp ?? 'Unknown',
        isReady: true,
      );
      _players.add(hostPlayer);
      _lobby.players.add(hostPlayer);
      
      // Set up initial game state
      _gameState = GameState();
      _playerId = 0;
      _gameState.spawnSnake(_playerId);
      _gameState.spawnFood();
      
      // Listen for client connections
      _server?.listen((Socket client) {
        print('Client connected: ${client.remoteAddress.address}');
        _connectedClients.add(client);
        
        // Send lobby info to new client
        _sendToClient(client, {
          'type': 'lobby_info',
          'lobby': _lobby.toJson(),
        });
        
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
      });
      
      // Start broadcasting lobby information
      _startBroadcasting();
      
      if (onConnectionStatusChanged != null) {
        onConnectionStatusChanged!(true);
      }
      
      return true;
    } catch (e) {
      print('Error hosting game: $e');
      String errorMsg = 'Error hosting game';
      
      // Provide more specific error messages based on the exception
      if (e.toString().contains('permission')) {
        errorMsg = 'Permission denied. Try using a different port or running on a device with proper permissions.';
      } else if (e.toString().contains('address already in use')) {
        errorMsg = 'Port is already in use. Try using a different port or restart the app.';
      } else if (e.toString().contains('network is unreachable')) {
        errorMsg = 'Network is unreachable. Check your WiFi connection.';
      } else {
        errorMsg = 'Error hosting game: $e';
      }
      
      if (onErrorMessage != null) {
        onErrorMessage!(errorMsg);
      }
      return false;
    }
  }
  
  // Join a game
  Future<bool> joinGame(String hostIp, int port, {required String playerName}) async {
    try {
      // Try to connect with a reasonable timeout
      _client = await Socket.connect(
        hostIp, 
        port,
        timeout: const Duration(seconds: 5),
      );
      print('Connected to game at $hostIp:$port');
      
      // Listen for messages from the host
      _client?.listen(
        _handleHostMessage,
        onError: (error) {
          print('Host error: $error');
          _client?.close();
          _client = null;
          if (onConnectionStatusChanged != null) {
            onConnectionStatusChanged!(false);
          }
          if (onErrorMessage != null) {
            onErrorMessage!('Lost connection to host: $error');
          }
        },
        onDone: () {
          print('Disconnected from host');
          _client?.close();
          _client = null;
          if (onConnectionStatusChanged != null) {
            onConnectionStatusChanged!(false);
          }
          if (onErrorMessage != null) {
            onErrorMessage!('Disconnected from host');
          }
        },
      );
      
      // Send player info to host
      _sendToHost({
        'type': 'join_lobby',
        'name': playerName,
        'ipAddress': await NetworkInfo().getWifiIP() ?? 'Unknown',
      });
      
      if (onConnectionStatusChanged != null) {
        onConnectionStatusChanged!(true);
      }
      
      return true;
    } catch (e) {
      print('Error joining game: $e');
      if (onErrorMessage != null) {
        onErrorMessage!('Error joining game: $e');
      }
      return false;
    }
  }
  
  // Broadcast lobby and game state to all clients periodically
  void _startBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_connectedClients.isEmpty) return;
      
      // If game is running, broadcast game state
      if (_isGameRunning) {
        final data = {
          'type': 'update',
          'gameState': _gameState.toJson(),
        };
        
        for (final client in _connectedClients) {
          _sendToClient(client, data);
        }
      } 
      // Otherwise broadcast lobby updates
      else {
        final data = {
          'type': 'lobby_update',
          'lobby': _lobby.toJson(),
        };
        
        for (final client in _connectedClients) {
          _sendToClient(client, data);
        }
      }
    });
  }
  
  // Start the game (host only)
  void startGame() {
    if (_server == null) return; // Not hosting
    
    // Ensure all players are ready
    if (!_lobby.players.every((p) => p.isReady)) {
      if (onErrorMessage != null) {
        onErrorMessage!('Not all players are ready');
      }
      return;
    }
    
    // Reset game state
    _gameState = GameState();
    
    // Spawn snakes for all players
    for (int i = 0; i < _lobby.players.length; i++) {
      _gameState.spawnSnake(i);
    }
    
    // Spawn initial food
    _gameState.spawnFood();
    
    // Set game running flag
    _isGameRunning = true;
    
    // Notify clients that game is starting
    for (final client in _connectedClients) {
      _sendToClient(client, {
        'type': 'game_start',
        'gameState': _gameState.toJson(),
      });
    }
    
    // Notify host UI
    if (onGameStarted != null) {
      onGameStarted!();
    }
  }
  
  // Handle messages from clients
  void _handleClientMessage(List<int> data, Socket client) {
    try {
      final message = json.decode(utf8.decode(data));
      
      switch (message['type']) {
        case 'get_lobby_info':
          // Send lobby info to the client that requested it
          _sendToClient(client, {
            'type': 'lobby_info',
            'lobby': _lobby.toJson(),
          });
          break;
          
        case 'player_leave':
          print('Player ${message['playerId']} is leaving');
          _handleClientDisconnect(client);
          break;
        case 'move':
          final playerId = message['playerId'];
          final direction = message['direction'];
          
          // Update snake direction
          for (final snake in _gameState.snakes) {
            if (snake.id == playerId) {
              snake.direction = direction;
              break;
            }
          }
          break;
          
        case 'join_lobby':
          final name = message['name'];
          final ipAddress = message['ipAddress'];
          
          // Check if lobby is full
          if (_lobby.players.length >= _lobby.maxPlayers) {
            _sendToClient(client, {
              'type': 'error',
              'message': 'Lobby is full',
            });
            return;
          }
          
          // Assign player ID
          final playerId = _lobby.players.length;
          
          // Create player
          final player = Player(
            id: playerId,
            name: name,
            ipAddress: ipAddress,
            isReady: false,
          );
          
          // Add to lobby
          _lobby.players.add(player);
          
          // Send player ID to client
          _sendToClient(client, {
            'type': 'player_id',
            'playerId': playerId,
          });
          
          // Broadcast updated lobby to all clients
          _lobbyUpdateController.add(_lobby);
          break;
          
        case 'ready_status':
          final playerId = message['playerId'];
          final isReady = message['isReady'];
          
          // Update player ready status
          for (var i = 0; i < _lobby.players.length; i++) {
            if (_lobby.players[i].id == playerId) {
              _lobby.players[i].isReady = isReady;
              break;
            }
          }
          
          // Broadcast updated lobby to all clients
          _lobbyUpdateController.add(_lobby);
          break;
      }
    } catch (e) {
      print('Error handling client message: $e');
    }
  }
  
  // Handle client disconnection
  void _handleClientDisconnect(Socket client) {
    final index = _connectedClients.indexOf(client);
    if (index >= 0) {
      _connectedClients.removeAt(index);
      
      // Find the player ID associated with this client
      final playerId = index + 1; // This is a simplification, might need improvement
      
      // Remove player from lobby
      _lobby.players.removeWhere((p) => p.id == playerId);
      
      // If game is running, remove snake from game state
      if (_isGameRunning) {
        _gameState.snakes.removeWhere((s) => s.id == playerId);
      }
      
      // Broadcast updated lobby to all clients
      _lobbyUpdateController.add(_lobby);
    }
  }
  
  // Handle messages from host
  void _handleHostMessage(List<int> data) {
    try {
      final message = json.decode(utf8.decode(data));
      
      switch (message['type']) {
        case 'init':
          _playerId = message['playerId'];
          _gameState = GameState.fromJson(message['gameState']);
          onGameStateUpdate(_gameState);
          break;
          
        case 'update':
          _gameState = GameState.fromJson(message['gameState']);
          onGameStateUpdate(_gameState);
          break;
          
        case 'lobby_info':
        case 'lobby_update':
          _lobby = GameLobby.fromJson(message['lobby']);
          _lobbyUpdateController.add(_lobby);
          break;
          
        case 'player_id':
          _playerId = message['playerId'];
          break;
          
        case 'game_start':
          _isGameRunning = true;
          _gameState = GameState.fromJson(message['gameState']);
          onGameStateUpdate(_gameState);
          if (onGameStarted != null) {
            onGameStarted!();
          }
          break;
          
        case 'error':
          if (onErrorMessage != null) {
            onErrorMessage!(message['message']);
          }
          break;
      }
    } catch (e) {
      print('Error handling host message: $e');
    }
  }
  
  // Send move to host
  void sendMove(String direction) {
    if (_client == null) return;
    
    final message = {
      'type': 'move',
      'playerId': _playerId,
      'direction': direction,
    };
    
    _sendToHost(message);
  }
  
  // Send ready status to host (client only)
  void sendReadyStatus(bool isReady) {
    if (_client == null) return;
    
    final message = {
      'type': 'ready_status',
      'playerId': _playerId,
      'isReady': isReady,
    };
    
    _sendToHost(message);
  }
  
  // Update game state (for host)
  void updateGameState() {
    if (_server == null) return; // Not hosting
    
    _gameState.update();
    onGameStateUpdate(_gameState);
  }
  
  // Client-specific disconnect method
  void disconnect() {
    print('Disconnecting from host');
    
    // Notify host about disconnection
    if (_client != null) {
      try {
        _sendToHost({
          'type': 'player_leave',
          'playerId': _playerId,
        });
      } catch (e) {
        print('Error sending disconnect message: $e');
      }
    }
    
    // Close client socket
    _client?.close();
    _client = null;
    
    if (onConnectionStatusChanged != null) {
      onConnectionStatusChanged!(false);
    }
  }
  
  // Close all connections
  void dispose() {
    _broadcastTimer?.cancel();
    _server?.close();
    _client?.close();
    _lobbyUpdateController.close();
    
    for (final client in _connectedClients) {
      client.close();
    }
    
    _connectedClients.clear();
  }
  
  // Helper: Send message to client
  void _sendToClient(Socket client, Map<String, dynamic> message) {
    try {
      client.write(json.encode(message));
    } catch (e) {
      print('Error sending to client: $e');
    }
  }
  
  // Helper: Send message to host
  void _sendToHost(Map<String, dynamic> message) {
    try {
      _client?.write(json.encode(message));
    } catch (e) {
      print('Error sending to host: $e');
    }
  }
  
  // Host discovery
  Future<List<GameLobby>> discoverHosts() async {
    List<GameLobby> discoveredGames = [];
    
    if (_localIp == null) {
      await initialize();
    }
    
    if (_localIp == null) {
      throw Exception('Could not determine local IP address');
    }
    
    try {
      // Get the subnet base from the local IP
      final ipBase = _localIp!.substring(0, _localIp!.lastIndexOf('.') + 1);
      final futures = <Future>[];
      final discoveredIps = <String>{};
      
      // Try to connect to potential hosts in the subnet
      for (int i = 1; i < 255; i++) {
        final targetIp = '$ipBase$i';
        
        // Skip our own IP
        if (targetIp == _localIp) continue;
        
        // Try to connect with a short timeout
        futures.add(
          Socket.connect(targetIp, defaultPort, timeout: const Duration(milliseconds: 200))
              .then((socket) {
                discoveredIps.add(targetIp);
                socket.destroy();
              })
              .catchError((_) {
                // Ignore connection errors - this is expected for most IPs
              })
        );
      }
      
      // Wait for all connection attempts to complete
      await Future.wait(futures);
      
      // For each discovered IP, try to get lobby info
      for (final ip in discoveredIps) {
        try {
          final socket = await Socket.connect(ip, defaultPort, timeout: const Duration(seconds: 1));
          
          // Send a request for lobby info
          final requestMessage = {
            'type': 'get_lobby_info',
          };
          socket.write(json.encode(requestMessage));
          
          // Wait for response with a timeout
          final completer = Completer<GameLobby?>();
          StreamSubscription? subscription;
          
          subscription = socket.listen(
            (data) {
              try {
                final response = json.decode(utf8.decode(data));
                if (response['type'] == 'lobby_info' && response.containsKey('lobby')) {
                  final lobby = GameLobby.fromJson(response['lobby']);
                  completer.complete(lobby);
                }
              } catch (e) {
                print('Error parsing lobby info: $e');
              }
            },
            onError: (e) {
              completer.complete(null);
            },
            onDone: () {
              if (!completer.isCompleted) {
                completer.complete(null);
              }
            },
          );
          
          // Add a timeout
          Future.delayed(const Duration(seconds: 1), () {
            if (!completer.isCompleted) {
              completer.complete(null);
            }
            subscription?.cancel();
            socket.destroy();
          });
          
          final lobby = await completer.future;
          if (lobby != null) {
            discoveredGames.add(lobby);
          }
        } catch (e) {
          // Ignore connection errors
          print('Error connecting to $ip: $e');
        }
      }
      
      return discoveredGames;
    } catch (e) {
      print('Error discovering hosts: $e');
      return [];
    }
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
}
