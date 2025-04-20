import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../models/game_state.dart';
import '../networking/simple_network_manager.dart';

class GameScreen extends StatefulWidget {
  final bool isHost;
  final String? hostIp;
  final int port;
  final String playerName;

  const GameScreen({
    Key? key,
    required this.isHost,
    this.hostIp,
    this.port = 8080,
    this.playerName = 'Player',
  }) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState gameState;
  late SimpleNetworkManager network;
  bool paused = false;
  Timer? _timer;
  int _tickMs = 400; // Slower speed for better playability, changed from final to allow modification
  int cols = 15; // Increased from 12 for better gameplay
  int rows = 20; // Increased from 18 for better gameplay
  double cellSize = 0; // Will be calculated based on screen size
  bool useSwipeControls = true; // Default to swipe controls
  
  // For swipe detection
  Offset? _startSwipePosition;
  final double _minSwipeDistance = 20.0;

  @override
  void initState() {
    super.initState();
    // Initialize game state
    gameState = GameState();
    
    // Initialize network manager
    network = SimpleNetworkManager(
      onGameStateUpdate: (state) {
        setState(() => gameState = state);
      },
      onErrorMessage: (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
          );
        }
      },
      onConnectionStatusChanged: (connected) {
        if (!connected && mounted) {
          // Show a message before returning to menu
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lost connection to game server'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Wait briefly before navigating back
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pop(context); // Return to menu if disconnected
            }
          });
        }
      },
      onGameStarted: () {
        // Game has started, make sure we're not paused
        setState(() {
          paused = false;
        });
      },
    );
    
    // Set up networking
    _setupNetwork();
    
    // Start game loop
    _startGameLoop();
  }
  
  Future<void> _setupNetwork() async {
    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Setting up network...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    
    try {
      await network.initialize();
      
      if (widget.isHost) {
        // Host mode
        final success = await network.hostGame(
          widget.port,
          hostName: widget.playerName,
        );
        
        // Dismiss loading indicator
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        
        if (!success) {
          print('Failed to host game. Running in single player mode.');
          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to host multiplayer game. Running in single player mode.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          // Create local game with a snake if hosting failed
          gameState.spawnSnake(0);
          gameState.spawnFood(cols: cols, rows: rows);
        } else {
          // Show hosting info if successful
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hosting game at ${network.lobby.hostIp}:${network.lobby.port}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        // Join mode
        if (widget.hostIp != null) {
          final success = await network.joinGame(
            widget.hostIp!,
            widget.port,
            playerName: widget.playerName,
          );
          
          // Dismiss loading indicator
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          
          if (!success) {
            print('Failed to join game');
            // Show error message and navigate back to menu on failure
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to join game. Check the host IP and make sure the host is online.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
              
              // Navigate back after showing the error
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  Navigator.pop(context);
                }
              });
            }
          } else {
            // Show success message when joined
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Successfully joined ${network.lobby.hostName}\'s game'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          // Dismiss loading indicator
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          
          // No host IP provided
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No host IP provided. Cannot join game.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            
            // Navigate back after showing the error
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.pop(context);
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error setting up network: $e');
      
      // Dismiss loading indicator
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // If joining, navigate back after showing the error
        if (!widget.isHost) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        } else {
          // If hosting, fall back to single player
          gameState.spawnSnake(0);
          gameState.spawnFood(cols: cols, rows: rows);
        }
      }
    }
  }

  void _startGameLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _tickMs), (timer) {
      if (!paused && mounted) {
        setState(() {
          if (widget.isHost) {
            // Update game state only if host
            _updateGameState();
          }
        });
      }
    });
  }

  // Update game state logic
  void _updateGameState() {
    // In multiplayer, only the host updates the game state
    if (!widget.isHost) return;
    
    // Move snakes
    for (var snake in gameState.snakes) {
      if (snake.isDead) continue;
      
      final head = snake.positions.first;
      Offset newHead;
      
      // Determine new head position based on direction
      switch (snake.direction) {
        case 'up':
          newHead = Offset(head.dx, head.dy - 1);
          break;
        case 'down':
          newHead = Offset(head.dx, head.dy + 1);
          break;
        case 'left':
          newHead = Offset(head.dx - 1, head.dy);
          break;
        case 'right':
          newHead = Offset(head.dx + 1, head.dy);
          break;
        default:
          newHead = head;
      }
      
      // Check for border collision - STRICT boundary checking
      if (newHead.dx < 0 || newHead.dx >= cols || newHead.dy < 0 || newHead.dy >= rows) {
        snake.isDead = true;
        continue;
      }
      
      // Check for self collision (skip head)
      for (int i = 1; i < snake.positions.length; i++) {
        if (snake.positions[i] == newHead) {
          snake.isDead = true;
          break;
        }
      }
      if (snake.isDead) continue;
      
      // Check for collision with other snakes
      for (var otherSnake in gameState.snakes) {
        if (otherSnake == snake) continue;
        if (otherSnake.positions.contains(newHead)) {
          snake.isDead = true;
          break;
        }
      }
      if (snake.isDead) continue;
      
      // Move snake forward
      snake.positions.insert(0, newHead);
      
      // Check for food
      bool ateFood = false;
      for (int i = 0; i < gameState.foods.length; i++) {
        if (gameState.foods[i].position == newHead) {
          // Snake ate food
          snake.score += 10;
          gameState.foods.removeAt(i);
          ateFood = true;
          break;
        }
      }
      
      // If no food eaten, remove tail
      if (!ateFood) {
        snake.positions.removeLast();
      }
      
      // If food eaten, spawn new food
      if (ateFood) {
        gameState.spawnFood(cols: cols, rows: rows);
      }
    }
    
    // Check if game over (all snakes dead)
    bool allDead = gameState.snakes.every((s) => s.isDead);
    if (allDead && gameState.snakes.isNotEmpty) {
      // Reset game after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && widget.isHost) {
          _resetGame();
        }
      });
    }
    
    // In multiplayer mode, host must broadcast the updated state
    if (widget.isHost && gameState.snakes.isNotEmpty) {
      network.updateGameState(gameState);
    }
  }

  // Handle direction changes safely
  void _updateSnakeDirection(String newDirection) {
    // Find the player's snake (id matches network playerId)
    final mySnakes = gameState.snakes.where((s) => s.id == network.playerId);
    if (mySnakes.isEmpty) return;
    
    final mySnake = mySnakes.first;
    final current = mySnake.direction;
    
    // Prevent reversing direction
    if ((current == 'up' && newDirection == 'down') ||
        (current == 'down' && newDirection == 'up') ||
        (current == 'left' && newDirection == 'right') ||
        (current == 'right' && newDirection == 'left')) {
      return; // Ignore invalid direction changes
    }
    
    // In single player or as host
    if (widget.isHost) {
      setState(() {
        mySnake.direction = newDirection;
      });
    } 
    // In multiplayer as client
    else {
      // Send move to host
      network.sendMove(newDirection);
      
      // Also update locally for responsive feel
      setState(() {
        mySnake.direction = newDirection;
      });
    }
  }

  @override
  void dispose() {
    print('GameScreen being disposed');
    // Cancel game timer
    _timer?.cancel();
    
    // Explicitly clean up network resources
    network.dispose();
    
    super.dispose();
  }
  
  void _resetGame() {
    setState(() {
      if (widget.isHost) {
        // Host controls game reset
        gameState = GameState();
        gameState.spawnSnake(network.playerId, cols: cols, rows: rows);
        gameState.spawnFood(cols: cols, rows: rows);
        
        // In multiplayer mode, broadcast the updated state
        network.updateGameState(gameState);
      } else {
        // Clients just wait for the host to reset
        gameState = GameState();
      }
      paused = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate cell size based on screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final gameAreaWidth = screenSize.width - 32; // Account for margins
    final gameAreaHeight = screenSize.height - 150; // Account for top bar and margins
    
    // Calculate cell size to fit the screen while maintaining the grid ratio
    final cellWidth = gameAreaWidth / cols;
    final cellHeight = gameAreaHeight / rows;
    cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;
    
    return WillPopScope(
      onWillPop: () async {
        // Ensure proper cleanup when back button is pressed
        print('Back button pressed, cleaning up network resources');
        
        // Cancel game loop timer
        _timer?.cancel();
        
        // Clean up network resources
        network.dispose();
        
        // Allow navigation to proceed
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 3, 28, 70),
        body: SafeArea(
          child: Column(
            children: [
              // Top bar with controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.black.withOpacity(0.3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _topBarButton(
                          icon: Icons.pause,
                          label: paused ? 'Resume' : 'Pause',
                          onTap: () {
                            setState(() {
                              paused = !paused;
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        _topBarButton(
                          icon: Icons.refresh,
                          label: 'Reset',
                          onTap: _resetGame,
                        ),
                      ],
                    ),
                    Text(
                      'SCORE: ${_getPlayerScore()}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Arial',
                      ),
                    ),
                    Row(
                      children: [
                        _topBarButton(
                          icon: Icons.settings,
                          label: 'CONTROLS',
                          onTap: _showControlsDialog,
                        ),
                        const SizedBox(width: 16),
                        _topBarButton(
                          icon: Icons.exit_to_app,
                          label: 'EXIT',
                          onTap: () {
                            // Ensure proper cleanup before exiting
                            print('Exit button pressed, cleaning up network resources');
                            
                            // Cancel timer and clean up network
                            _timer?.cancel();
                            network.dispose();
                            
                            // Return to main menu
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Game area - takes maximum available space
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              // Game canvas
                              CustomPaint(
                                painter: GamePainter(
                                  gameState,
                                  cellSize: cellSize,
                                  cols: cols,
                                  rows: rows,
                                  playerNames: network.playerNames,
                                ),
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                              ),
                              
                              // Game over overlay if any snake is dead
                              if (gameState.snakes.any((s) => s.isDead))
                                _buildGameOverScreen(),
                              
                              // Swipe detector for the entire game area
                              if (useSwipeControls && !gameState.snakes.any((s) => s.isDead))
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (details) {
                                    _startSwipePosition = details.localPosition;
                                  },
                                  onPanUpdate: (details) {
                                    if (_startSwipePosition != null) {
                                      final currentPosition = details.localPosition;
                                      final dx = currentPosition.dx - _startSwipePosition!.dx;
                                      final dy = currentPosition.dy - _startSwipePosition!.dy;
                                      
                                      // Only process swipe if it's long enough
                                      if (dx.abs() > _minSwipeDistance || dy.abs() > _minSwipeDistance) {
                                        // Determine swipe direction
                                        if (dx.abs() > dy.abs()) {
                                          // Horizontal swipe
                                          _updateSnakeDirection(dx > 0 ? 'right' : 'left');
                                        } else {
                                          // Vertical swipe
                                          _updateSnakeDirection(dy > 0 ? 'down' : 'up');
                                        }
                                        // Reset start position to prevent multiple triggers
                                        _startSwipePosition = null;
                                      }
                                    }
                                  },
                                  onPanEnd: (details) {
                                    _startSwipePosition = null;
                                  },
                                ),
                              
                              // Control buttons if not using swipe
                              if (!useSwipeControls && !gameState.snakes.any((s) => s.isDead))
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 150,
                                    color: Colors.black.withOpacity(0.3),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 40),
                                              onPressed: () => _updateSnakeDirection('up'),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 40),
                                              onPressed: () => _updateSnakeDirection('left'),
                                            ),
                                            const SizedBox(width: 60),
                                            IconButton(
                                              icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 40),
                                              onPressed: () => _updateSnakeDirection('right'),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 40),
                                              onPressed: () => _updateSnakeDirection('down'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    // Find the player's snake
    final playerSnakes = gameState.snakes.where((s) => s.id == network.playerId);
    final playerSnake = playerSnakes.isNotEmpty 
        ? playerSnakes.first 
        : Snake(network.playerId, [], 'right', 0, score: 0);
    
    // Find the highest scoring snake to determine winner
    int highestScore = 0;
    String winnerName = "";
    
    for (var snake in gameState.snakes) {
      if (snake.score > highestScore) {
        highestScore = snake.score;
        winnerName = network.playerNames[snake.id] ?? 'Player ${snake.id}';
      }
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                fontSize: 32,
                color: Colors.white,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                fontFamily: 'Arial',
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.red,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (winnerName.isNotEmpty && gameState.snakes.length > 1)
              Text(
                'WINNER: $winnerName',
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.yellow,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Arial',
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'YOUR SCORE: ${playerSnake.score}',
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
                fontFamily: 'Arial',
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _resetGame,
              child: const Text(
                'PLAY AGAIN',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Arial',
                  shadows: [
                    Shadow(
                      blurRadius: 8.0,
                      color: Colors.green,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () {
                // Ensure proper cleanup before exiting
                print('Main menu button pressed, cleaning up network resources');
                
                // Cancel timer and clean up network
                _timer?.cancel();
                network.dispose();
                
                // Return to main menu
                Navigator.pop(context);
              },
              child: const Text(
                'MAIN MENU',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Arial',
                  shadows: [
                    Shadow(
                      blurRadius: 8.0,
                      color: Colors.blue,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getPlayerScore() {
    final playerSnake = gameState.snakes.firstWhere(
      (s) => s.id == network.playerId,
      orElse: () => Snake(network.playerId, [], 'right', 0, score: 0),
    );
    return playerSnake.score;
  }

  void _showControlsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Controls'),
        content: SizedBox(
          height: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Control Method:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildControlOption(
                'Button Controls',
                false,
                useSwipeControls,
                (value) => setState(() => useSwipeControls = value),
              ),
              _buildControlOption(
                'Swipe Controls',
                true,
                useSwipeControls,
                (value) => setState(() => useSwipeControls = value),
              ),
              const SizedBox(height: 16),
              const Text(
                'Game Speed:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _tickMs.toDouble(),
                min: 200,
                max: 600,
                divisions: 4,
                label: _tickMs <= 250 ? 'Fast' : _tickMs >= 500 ? 'Slow' : 'Normal',
                onChanged: (value) {
                  setState(() {
                    _tickMs = value.round();
                    // Restart game loop with new speed
                    _startGameLoop();
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {}); // Update the UI with the selected control method
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlOption(String label, bool value, bool groupValue, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Radio<bool>(
          value: value,
          groupValue: groupValue,
          onChanged: (value) => onChanged(value!),
        ),
      ],
    );
  }

  Widget _topBarButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: Colors.white),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'Arial',
            ),
          ),
        ],
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final GameState gameState;
  final double cellSize;
  final int cols;
  final int rows;
  final Map<int, String> playerNames;

  GamePainter(
    this.gameState, {
    this.cellSize = 32,
    this.cols = 12,
    this.rows = 18,
    this.playerNames = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the actual game area size based on the cell size and grid dimensions
    final gameWidth = cols * cellSize;
    final gameHeight = rows * cellSize;
    
    // Center the game area within the available space
    final offsetX = (size.width - gameWidth) / 2;
    final offsetY = (size.height - gameHeight) / 2;
    
    // Draw background
    final paint = Paint()..color = const Color.fromARGB(255, 3, 28, 70);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw game area border
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    canvas.drawRect(
      Rect.fromLTWH(offsetX, offsetY, gameWidth, gameHeight),
      paint
    );
    paint.style = PaintingStyle.fill;
    
    // Draw grid lines (optional, for better visibility)
    paint.color = Colors.white.withOpacity(0.1);
    paint.strokeWidth = 1;
    
    // Vertical grid lines
    for (int i = 1; i < cols; i++) {
      final x = offsetX + i * cellSize;
      canvas.drawLine(
        Offset(x, offsetY),
        Offset(x, offsetY + gameHeight),
        paint
      );
    }
    
    // Horizontal grid lines
    for (int i = 1; i < rows; i++) {
      final y = offsetY + i * cellSize;
      canvas.drawLine(
        Offset(offsetX, y),
        Offset(offsetX + gameWidth, y),
        paint
      );
    }

    // Draw food as apple emoji 🍎
    for (var food in gameState.foods) {
      final textSpan = TextSpan(
        text: '🍎',
        style: TextStyle(fontSize: cellSize * 0.9),
      );
      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(
          offsetX + food.position.dx * cellSize + (cellSize - tp.width) / 2,
          offsetY + food.position.dy * cellSize + (cellSize - tp.height) / 2,
        ),
      );
    }

    // Draw snakes (with their proper colors, rounded, head with eyes)
    for (var snake in gameState.snakes) {
      // Skip empty snakes
      if (snake.positions.isEmpty) continue;
      
      // Draw player name above the snake's head
      if (snake.positions.isNotEmpty && playerNames.containsKey(snake.id)) {
        final head = snake.positions.first;
        final playerName = playerNames[snake.id] ?? 'Player ${snake.id}';
        final textSpan = TextSpan(
          text: playerName,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 2.0,
                color: Colors.black,
                offset: Offset(1, 1),
              ),
            ],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            offsetX + head.dx * cellSize + (cellSize - textPainter.width) / 2,
            offsetY + head.dy * cellSize - textPainter.height - 2,
          ),
        );
      }
      
      for (int i = 0; i < snake.positions.length; i++) {
        final pos = snake.positions[i];
        final isHead = i == 0;
        
        // Skip if position is outside the grid (shouldn't happen with fixed boundaries)
        if (pos.dx < 0 || pos.dx >= cols || pos.dy < 0 || pos.dy >= rows) {
          continue;
        }
        
        // Use snake's color property
        paint.color = isHead 
          ? snake.color.withOpacity(0.8) 
          : snake.color.withOpacity(0.6);
        
        // Create rectangle with proper offset
        final rect = Rect.fromLTWH(
          offsetX + pos.dx * cellSize, 
          offsetY + pos.dy * cellSize, 
          cellSize, 
          cellSize
        );
        
        // Draw rounded rectangle for snake segment
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.45));
        canvas.drawRRect(rrect, paint);
        
        if (isHead) {
          // Draw eyes (two white dots)
          final eyeRadius = cellSize * 0.10;
          final dx = offsetX + pos.dx * cellSize + cellSize * 0.30;
          final dy = offsetY + pos.dy * cellSize + cellSize * 0.30;
          final dx2 = offsetX + pos.dx * cellSize + cellSize * 0.70;
          final dy2 = dy;
          final eyePaint = Paint()..color = Colors.white;
          canvas.drawCircle(Offset(dx, dy), eyeRadius, eyePaint);
          canvas.drawCircle(Offset(dx2, dy2), eyeRadius, eyePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}