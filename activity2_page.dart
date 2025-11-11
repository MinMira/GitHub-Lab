import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

const int EMPTY = 0;
const int WALL = 1;
const int DOG = 2;
const int FISH = 3;

class Activity2Page extends StatefulWidget {
  const Activity2Page({super.key});

  @override
  State<Activity2Page> createState() => _Activity2PageState();
}

class _Activity2PageState extends State<Activity2Page> {
  late List<List<int>> maze;
  int catRow = 0;
  int catCol = 0;
  int score = 0;
  int level = 1;
  bool gameOver = false;
  bool gameWin = false;

  List<Map<String, int>> dogs = [];

  final FocusNode _focusNode = FocusNode();
  final Random random = Random();
  Timer? dogTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
    generateMaze();
    startDogMovement();
  }

  void startDogMovement() {
    dogTimer?.cancel();
    dogTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!gameOver && !gameWin) {
        setState(() {
          for (var dog in dogs) {
            List<List<int>> moves = [];
            
            // Check all possible moves
            if (dog['row']! > 0 && maze[dog['row']! - 1][dog['col']!] != WALL)
              moves.add([-1, 0]);
            if (dog['row']! < maze.length - 1 &&
                maze[dog['row']! + 1][dog['col']!] != WALL)
              moves.add([1, 0]);
            if (dog['col']! > 0 && maze[dog['row']!][dog['col']! - 1] != WALL)
              moves.add([0, -1]);
            if (dog['col']! < maze[0].length - 1 &&
                maze[dog['row']!][dog['col']! + 1] != WALL)
              moves.add([0, 1]);

            if (moves.isNotEmpty) {
              var move = moves[random.nextInt(moves.length)];
              int newRow = dog['row']! + move[0];
              int newCol = dog['col']! + move[1];
              
              // Check if another dog is already at this position
              bool occupied = dogs.any((d) => 
                d != dog && d['row'] == newRow && d['col'] == newCol);
              
              if (!occupied) {
                dog['row'] = newRow;
                dog['col'] = newCol;
              }
            }
          }

          // Check collision with cat
          for (var dog in dogs) {
            if (dog['row'] == catRow && dog['col'] == catCol) {
              gameOver = true;
            }
          }
        });
      }
    });
  }

  void generateMaze() {
    int rows = 7 + level;
    int cols = 9 + level;

    maze = List.generate(rows, (_) => List.generate(cols, (_) => WALL));

    final directions = [
      [-2, 0],
      [2, 0],
      [0, -2],
      [0, 2],
    ];

    void carve(int r, int c) {
      maze[r][c] = EMPTY;
      directions.shuffle(random);
      for (var dir in directions) {
        int nr = r + dir[0];
        int nc = c + dir[1];
        if (nr > 0 &&
            nr < rows - 1 &&
            nc > 0 &&
            nc < cols - 1 &&
            maze[nr][nc] == WALL) {
          maze[r + dir[0] ~/ 2][c + dir[1] ~/ 2] = EMPTY;
          carve(nr, nc);
        }
      }
    }

    // Start carving from top-left to ensure cat position is accessible
    carve(1, 1);

    // Make maze more open: random extra empty spaces
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        if (maze[i][j] == WALL && random.nextDouble() < 0.25) {
          maze[i][j] = EMPTY;
        }
      }
    }

    // Set cat position at top-left
    catRow = 0;
    catCol = 0;
    maze[catRow][catCol] = EMPTY;

    // Set fish position at bottom-right
    int fishRow = rows - 1;
    int fishCol = cols - 1;

    // Clear walls around cat (safe zone) - but don't overwrite fish
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        int rr1 = catRow + dr;
        int cc1 = catCol + dc;
        if (rr1 >= 0 && rr1 < rows && cc1 >= 0 && cc1 < cols) {
          maze[rr1][cc1] = EMPTY;
        }
      }
    }

    // Clear walls around fish (safe zone)
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        int rr2 = fishRow + dr;
        int cc2 = fishCol + dc;
        if (rr2 >= 0 && rr2 < rows && cc2 >= 0 && cc2 < cols) {
          maze[rr2][cc2] = EMPTY;
        }
      }
    }

    // NOW place the fish AFTER clearing the safe zone
    maze[fishRow][fishCol] = FISH;

    // Place dogs randomly, avoiding cat, fish, and their safe zones
    dogs.clear();
    int numDogs = max(2, level + 1);
    for (int d = 0; d < numDogs; d++) {
      int r, c;
      int attempts = 0;
      do {
        r = random.nextInt(rows);
        c = random.nextInt(cols);
        attempts++;
        // Prevent infinite loop
        if (attempts > 100) break;
      } while (maze[r][c] != EMPTY ||
          (r <= 2 && c <= 2) || // Avoid cat safe zone
          (r >= rows - 3 && c >= cols - 3) || // Avoid fish safe zone
          dogs.any((d) => d['row'] == r && d['col'] == c)); // Avoid other dogs
      
      if (attempts <= 100) {
        dogs.add({'row': r, 'col': c});
      }
    }
  }

  void moveCat(int dRow, int dCol) {
    if (gameOver || gameWin) return;
    int newRow = catRow + dRow;
    int newCol = catCol + dCol;
    if (newRow < 0 || newRow >= maze.length) return;
    if (newCol < 0 || newCol >= maze[0].length) return;
    if (maze[newRow][newCol] == WALL) return;

    setState(() {
      catRow = newRow;
      catCol = newCol;
      score += 1;

      // Check if cat reached the fish
      if (maze[newRow][newCol] == FISH) {
        gameWin = true;
      }
      
      // Check collision with dogs
      for (var dog in dogs) {
        if (dog['row'] == catRow && dog['col'] == catCol) {
          gameOver = true;
        }
      }
    });
  }

  void nextLevel() {
    setState(() {
      level += 1;
      score = 0;
      gameOver = false;
      gameWin = false;
      generateMaze();
      startDogMovement();
    });
  }

  void resetGame() {
    setState(() {
      level = 1;
      score = 0;
      gameOver = false;
      gameWin = false;
      generateMaze();
      startDogMovement();
    });
  }

  @override
  void dispose() {
    dogTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F8),
      appBar: AppBar(
        title: const Text("Cat Maze Mission 🐾"),
        backgroundColor: const Color(0xFFF48FB1),
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.keyW ||
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              moveCat(-1, 0);
            }
            if (event.logicalKey == LogicalKeyboardKey.keyS ||
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              moveCat(1, 0);
            }
            if (event.logicalKey == LogicalKeyboardKey.keyA ||
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              moveCat(0, -1);
            }
            if (event.logicalKey == LogicalKeyboardKey.keyD ||
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              moveCat(0, 1);
            }
          }
        },
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: maze.asMap().entries.map((rowEntry) {
                      int rowIndex = rowEntry.key;
                      List<int> row = rowEntry.value;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: row.asMap().entries.map((colEntry) {
                          int colIndex = colEntry.key;
                          int value = row[colIndex];
                          Widget content;

                          if (catRow == rowIndex && catCol == colIndex) {
                            content = Image.asset('assets/cat.jpg',
                                width: 60, height: 60, fit: BoxFit.cover);
                          } else if (dogs.any((d) =>
                              d['row'] == rowIndex && d['col'] == colIndex)) {
                            content = Image.asset('assets/dog_awake.jpg',
                                width: 60, height: 60, fit: BoxFit.cover);
                          } else if (value == FISH) {
                            content = Image.asset('assets/fish.jpg',
                                width: 60, height: 60, fit: BoxFit.cover);
                          } else if (value == WALL) {
                            content = Image.asset('assets/wall.jpg',
                                width: 60, height: 60, fit: BoxFit.cover);
                          } else {
                            content = Container(
                              width: 60,
                              height: 60,
                              color: const Color(0xFFFFF5F8),
                            );
                          }

                          return content;
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 30,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Score: $score | Level: $level",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD81B60),
                  ),
                ),
              ),
            ),
            if (gameOver || gameWin)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          gameWin
                              ? "You got the Fish! 🐟💖"
                              : "Caught by Dog! 🐶",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: gameWin
                                ? const Color(0xFFD81B60)
                                : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text("Score: $score",
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: gameWin ? nextLevel : resetGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF48FB1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                          ),
                          child: Text(
                            gameWin ? "Next Level 💕" : "Play Again 💕",
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
