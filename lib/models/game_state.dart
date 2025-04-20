import 'dart:math';
import 'package:flutter/material.dart';

class Snake {
  int id;
  List<Offset> positions;
  String direction;
  int length;
  bool isDead;
  int score;
  Color color; // Added color property for different snake colors

  Snake(this.id, this.positions, this.direction, this.length, {
    this.isDead = false, 
    this.score = 0,
    Color? color,
  }) : color = color ?? _getDefaultColor(id);
  
  // Get default color based on player ID
  static Color _getDefaultColor(int id) {
    // Avoid red (for apples) and ensure no two snakes have the same color
    final colors = [
      const Color(0xFF00FF00), // Green
      const Color(0xFF0000FF), // Blue
      const Color(0xFFFFFF00), // Yellow
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFFFF8000), // Orange
      const Color(0xFF8000FF), // Purple
      const Color(0xFF00FF80), // Mint
    ];
    
    return colors[id % colors.length];
  }
}

class Food {
  Offset position;
  Food(this.position);
}

class GameState {
  static const int gridWidth = 20;
  static const int gridHeight = 20;
  List<Snake> snakes = [];
  List<Food> foods = [];

  void spawnSnake(int id, {int cols = 20, int rows = 20}) {
    // Ensure snake spawns within boundaries
    final startX = (cols / 2).floor().toDouble().clamp(0.0, (cols - 1).toDouble());
    final startY = (rows / 2).floor().toDouble().clamp(0.0, (rows - 1).toDouble());
    snakes.add(Snake(id, [Offset(startX, startY)], 'right', 2, isDead: false, score: 0));
  }

  void spawnFood({int? cols, int? rows}) {
    // Ensure cols and rows are valid
    cols = cols?.clamp(1, 100) ?? 20;
    rows = rows?.clamp(1, 100) ?? 20;
    
    Random rand = Random();
    Offset pos;
    
    // Try up to 100 times to find a valid position
    int attempts = 0;
    bool validPosition = false;
    
    do {
      // Generate position strictly within the boundaries
      final x = rand.nextInt(cols);
      final y = rand.nextInt(rows);
      pos = Offset(x.toDouble(), y.toDouble());
      
      // Check if position is valid (not occupied by snake)
      validPosition = !snakes.any((s) => s.positions.contains(pos)) && 
                     !foods.any((f) => f.position == pos);
      
      attempts++;
      // If we've tried too many times, just place it somewhere valid
      if (attempts > 100) {
        // Find first empty cell
        for (int y = 0; y < rows; y++) {
          for (int x = 0; x < cols; x++) {
            final testPos = Offset(x.toDouble(), y.toDouble());
            if (!snakes.any((s) => s.positions.contains(testPos)) && 
                !foods.any((f) => f.position == testPos)) {
              pos = testPos;
              validPosition = true;
              break;
            }
          }
          if (validPosition) break;
        }
        break;
      }
    } while (!validPosition);
    
    // Add the food at the valid position
    foods.add(Food(pos));
  }

  void update() {
    // We'll track snakes that need to be removed due to collisions
    
    for (var snake in snakes) {
      // Skip dead snakes
      if (snake.isDead) continue;
      
      var head = snake.positions.first;
      Offset newHead;
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

      // Check for wall collision
      if (newHead.dx < 0 ||
          newHead.dx >= gridWidth ||
          newHead.dy < 0 ||
          newHead.dy >= gridHeight) {
        snake.isDead = true;
        continue;
      }
      
      // Check for self collision
      if (snake.positions.contains(newHead)) {
        snake.isDead = true;
        continue;
      }
      
      // Check for food collision - Growth rule
      if (foods.any((f) => f.position == newHead)) {
        snake.positions.insert(0, newHead);
        snake.score += 1; // Increase score when eating food
        foods.removeWhere((f) => f.position == newHead);
        spawnFood();
      } else {
        snake.positions.insert(0, newHead);
        if (snake.positions.length > snake.length) {
          snake.positions.removeLast();
        }
      }
      
      // Check for collisions with other snakes
      for (var other in snakes) {
        if (other == snake) continue; // Skip self
        
        // Face-to-face encounter rule
        if (other.positions.isNotEmpty && newHead == other.positions.first) {
          // Head-to-head collision
          if (snake.score == other.score) {
            // Draw - both die
            snake.isDead = true;
            other.isDead = true;
          } else if (snake.score > other.score) {
            // Snake has more points, it wins
            other.isDead = true;
          } else {
            // Other snake has more points, it wins
            snake.isDead = true;
          }
        }
        
        // Underdog advantage rule - smaller snake lands on head of larger snake
        else if (other.positions.isNotEmpty && 
                 newHead == other.positions.first && 
                 snake.score < other.score) {
          // Smaller snake wins
          other.isDead = true;
        }
        
        // Body interference rule - snake passes through body of another snake
        else if (other.positions.length > 1 && 
                 other.positions.sublist(1).contains(newHead)) {
          // Snake loses points when passing through another snake's body
          if (other.score > 0) {
            other.score -= 1;
          }
          
          // Remove a segment from the other snake
          if (other.positions.length > 2) {
            other.positions.removeLast();
          }
        }
      }
      
      // If snake died during collision checks, continue to next snake
      if (snake.isDead) continue;
    }
    
    // Remove dead snakes
    snakes.removeWhere((s) => s.isDead);
  }

  Map<String, dynamic> toJson() => {
        'snakes': snakes
            .map((s) => {
                  'id': s.id,
                  'positions':
                      s.positions.map((p) => [p.dx, p.dy]).toList(),
                  'direction': s.direction,
                  'length': s.length,
                  'isDead': s.isDead,
                  'score': s.score,
                  'color': {
                    'r': s.color.red,
                    'g': s.color.green,
                    'b': s.color.blue,
                    'a': s.color.alpha,
                  },
                })
            .toList(),
        'foods': foods.map((f) => [f.position.dx, f.position.dy]).toList(),
      };

  static GameState fromJson(Map<String, dynamic> json) {
    var state = GameState();
    state.snakes = (json['snakes'] as List)
        .map((s) {
          Color? snakeColor;
          if (s['color'] != null) {
            snakeColor = Color.fromARGB(
              s['color']['a'] ?? 255,
              s['color']['r'] ?? 0,
              s['color']['g'] ?? 0,
              s['color']['b'] ?? 0,
            );
          }
          
          return Snake(
              s['id'],
              (s['positions'] as List)
                  .map((p) => Offset(p[0].toDouble(), p[1].toDouble()))
                  .toList(),
              s['direction'],
              s['length'],
              isDead: s['isDead'] ?? false,
              score: s['score'] ?? 0,
              color: snakeColor,
            );
        })
        .toList();
    state.foods = (json['foods'] as List)
        .map((f) => Food(Offset(f[0].toDouble(), f[1].toDouble())))
        .toList();
    return state;
  }
}