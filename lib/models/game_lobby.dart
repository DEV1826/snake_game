import 'dart:convert';

/// A class representing a game lobby that can be discovered on the network
class GameLobby {
  final String hostName;
  final String hostIp;
  final int port;
  final int maxPlayers;
  final List<Player> players;
  final int currentPlayers;

  GameLobby({
    required this.hostName,
    required this.hostIp, 
    required this.port,
    this.maxPlayers = 4,
    List<Player>? players,
    int? currentPlayers,
  }) : 
    players = players ?? [],
    currentPlayers = currentPlayers ?? (players?.length ?? 0);

  Map<String, dynamic> toJson() {
    return {
      'hostName': hostName,
      'hostIp': hostIp,
      'port': port,
      'maxPlayers': maxPlayers,
      'players': players.map((p) => p.toJson()).toList(),
      'currentPlayers': currentPlayers,
    };
  }

  factory GameLobby.fromJson(Map<String, dynamic> json) {
    return GameLobby(
      hostName: json['hostName'],
      hostIp: json['hostIp'],
      port: json['port'],
      maxPlayers: json['maxPlayers'],
      players: (json['players'] as List?)
          ?.map((p) => Player.fromJson(p))
          .toList() ?? [],
      currentPlayers: json['currentPlayers'],
    );
  }
  
  // For network broadcasting
  String toJsonString() {
    return jsonEncode(toJson());
  }
  
  factory GameLobby.fromJsonString(String jsonString) {
    return GameLobby.fromJson(jsonDecode(jsonString));
  }
}

/// A class representing a player in a game lobby
class Player {
  final int id;
  final String name;
  final String ipAddress;
  bool isReady;

  Player({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.isReady = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'isReady': isReady,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'],
      ipAddress: json['ipAddress'],
      isReady: json['isReady'] ?? false,
    );
  }
}
