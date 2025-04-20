import 'dart:async';
import 'dart:io';

/// A utility class to help manage socket cleanup across the application.
/// This ensures that all network resources are properly released when the app exits.
class SocketCleanup {
  // Static list to keep track of all active server sockets
  static final List<ServerSocket> _activeServerSockets = [];
  
  // Static list to keep track of all active client sockets
  static final List<Socket> _activeClientSockets = [];
  
  /// Register a server socket for cleanup
  static void registerServerSocket(ServerSocket socket) {
    if (!_activeServerSockets.contains(socket)) {
      print('Registering server socket on port ${socket.port} for cleanup');
      _activeServerSockets.add(socket);
    }
  }
  
  /// Register a client socket for cleanup
  static void registerClientSocket(Socket socket) {
    if (!_activeClientSockets.contains(socket)) {
      print('Registering client socket to ${socket.remoteAddress.address}:${socket.remotePort} for cleanup');
      _activeClientSockets.add(socket);
    }
  }
  
  /// Unregister a server socket
  static void unregisterServerSocket(ServerSocket socket) {
    _activeServerSockets.remove(socket);
    print('Unregistered server socket on port ${socket.port}');
  }
  
  /// Unregister a client socket
  static void unregisterClientSocket(Socket socket) {
    _activeClientSockets.remove(socket);
    print('Unregistered client socket');
  }
  
  /// Close all sockets when app is shutting down
  static Future<void> closeAllSockets() async {
    print('SocketCleanup: Closing all sockets on app exit');
    
    // First close all client sockets
    for (final socket in _activeClientSockets) {
      try {
        socket.destroy();
        print('Closed client socket connection');
      } catch (e) {
        print('Error closing client socket: $e');
      }
    }
    _activeClientSockets.clear();
    
    // Then close all server sockets
    for (final serverSocket in _activeServerSockets) {
      try {
        await serverSocket.close();
        print('Closed server socket on port ${serverSocket.port}');
      } catch (e) {
        print('Error closing server socket: $e');
      }
    }
    _activeServerSockets.clear();
    
    print('All sockets closed successfully');
  }
}
