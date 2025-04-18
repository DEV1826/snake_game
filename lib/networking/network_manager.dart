import 'dart:io';
import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/game_state.dart';
import 'dart:async';

class NetworkManager {
  ServerSocket? server;
  List<Socket> clients = [];
  Socket? clientSocket;
  Function(GameState) onStateUpdate;
  int playerId = -1;

  NetworkManager(this.onStateUpdate);

  Future<String> getLocalIp() async {
    final info = NetworkInfo();
    return await info.getWifiIP() ?? '0.0.0.0';
  }

  Future<void> hostGame(int port, GameState gameState) async {
    server = await ServerSocket.bind('0.0.0.0', port);
    print('Hosting on ${await getLocalIp()}:$port');
    server!.listen((socket) {
      clients.add(socket);
      playerId = clients.length;
      gameState.spawnSnake(playerId);
      socket.listen((data) {
        var msg = jsonDecode(utf8.decode(data));
        if (msg['type'] == 'move') {
          var snake = gameState.snakes
              .firstWhere((s) => s.id == clients.indexOf(socket) + 1);
          snake.direction = msg['direction'];
        }
      });
    });

    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      gameState.update();
      var stateJson = jsonEncode(gameState.toJson());
      for (var client in clients) {
        client.write(stateJson);
      }
    });
  }

  Future<void> joinGame(String hostIp, int port, GameState gameState) async {
    clientSocket = await Socket.connect(hostIp, port);
    clientSocket!.write(jsonEncode({'type': 'join'}));
    clientSocket!.listen((data) {
      var state = GameState.fromJson(jsonDecode(utf8.decode(data)));
      onStateUpdate(state);
    });
  }

  void sendMove(String direction) {
    clientSocket?.write(jsonEncode({'type': 'move', 'direction': direction}));
  }
}