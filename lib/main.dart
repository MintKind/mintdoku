import 'package:flutter/material.dart';
import 'dart:async';
import 'sudoku_game_logic.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mintdoku',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A878),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        cardTheme: const CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const SudokuGame(),
    );
  }
}

class SudokuGame extends StatefulWidget {
  const SudokuGame({super.key});

  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> {
  late SudokuGameLogic gameLogic;
  int? selectedRow;
  int? selectedCol;
  int secondsElapsed = 0;
  late Timer timer;
  bool isGameComplete = false;
  bool isGameOver = false;
  bool isNoteMode = false;
  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    gameLogic = SudokuGameLogic(difficulty: Difficulty.medium);
    startTimer();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused) {
        setState(() {
          secondsElapsed++;
        });
      }
    });
  }

  String get formattedTime {
    final minutes = (secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsElapsed % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void selectCell(int row, int col) {
    setState(() {
      selectedRow = row;
      selectedCol = col;
      if (gameLogic.grid[row][col] != 0) {
        // If selecting a cell with a number, highlight all instances of that number and its notes
        selectNumber(gameLogic.grid[row][col]);
      } else {
        // For empty cells, only highlight row/column/box
        for (int i = 0; i < 9; i++) {
          for (int j = 0; j < 9; j++) {
            gameLogic.relatedCells[i][j] = false;
          }
        }
        
        // Highlight row
        for (int j = 0; j < 9; j++) {
          gameLogic.relatedCells[row][j] = true;
        }
        
        // Highlight column
        for (int i = 0; i < 9; i++) {
          gameLogic.relatedCells[i][col] = true;
        }
        
        // Highlight 3x3 box
        int boxRow = row - row % 3;
        int boxCol = col - col % 3;
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            gameLogic.relatedCells[boxRow + i][boxCol + j] = true;
          }
        }
        
        // Don't highlight the selected cell itself
        gameLogic.relatedCells[row][col] = false;
      }
    });
  }

  void selectNumber(int number) {
    setState(() {
      // Clear previous related cells
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          gameLogic.relatedCells[i][j] = false;
        }
      }
      
      // Only highlight cells that have this number as a value (not notes)
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          if (gameLogic.grid[i][j] == number) {
            gameLogic.relatedCells[i][j] = true;
          }
        }
      }
    });
  }

  void inputNumber(int number) {
    if (selectedRow != null && 
        selectedCol != null && 
        !isGameOver && 
        !gameLogic.fixedNumbers[selectedRow!][selectedCol!] &&
        !(gameLogic.grid[selectedRow!][selectedCol!] != 0 && 
          gameLogic.grid[selectedRow!][selectedCol!] == gameLogic.solution[selectedRow!][selectedCol!])) {
      setState(() {
        gameLogic.setCell(selectedRow!, selectedCol!, number);
        gameLogic.updateRelatedCells(selectedRow, selectedCol);
        if (gameLogic.isGameOver()) {
          isGameOver = true;
          timer.cancel();
          _showGameOverDialog();
        } else if (gameLogic.isComplete()) {
          isGameComplete = true;
          timer.cancel();
          _showCompletionDialog();
        }
      });
    }
  }

  void clearCell() {
    if (selectedRow != null && 
        selectedCol != null && 
        !gameLogic.fixedNumbers[selectedRow!][selectedCol!] &&
        !(gameLogic.grid[selectedRow!][selectedCol!] != 0 && 
          gameLogic.grid[selectedRow!][selectedCol!] == gameLogic.solution[selectedRow!][selectedCol!])) {
      setState(() {
        gameLogic.clearCell(selectedRow!, selectedCol!);
        gameLogic.updateRelatedCells(selectedRow, selectedCol);
      });
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Congratulations!'),
        content: Text('You completed the puzzle in $formattedTime!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              resetGame();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: const Text('You have made too many mistakes!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              resetGame();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  void _showHintDialog(LogicalHint hint) {
    // First apply the hint
    setState(() {
      gameLogic.useLogicalHint();
      selectedRow = hint.row;
      selectedCol = hint.col;
      
      // Highlight the relevant area for the hint
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          gameLogic.relatedCells[i][j] = false;
        }
      }

      // Highlight based on hint type
      if (hint.technique.contains('Row')) {
        // Highlight the entire row
        for (int j = 0; j < 9; j++) {
          gameLogic.relatedCells[hint.row][j] = true;
        }
      } else if (hint.technique.contains('Column')) {
        // Highlight the entire column
        for (int i = 0; i < 9; i++) {
          gameLogic.relatedCells[i][hint.col] = true;
        }
      } else if (hint.technique.contains('Box')) {
        // Highlight the 3x3 box
        int boxRow = hint.row - hint.row % 3;
        int boxCol = hint.col - hint.col % 3;
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            gameLogic.relatedCells[boxRow + i][boxCol + j] = true;
          }
        }
      }
      // The target cell itself gets a different highlight
      gameLogic.relatedCells[hint.row][hint.col] = false;
    });

    // Then show the explanation dialog
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final numberPadHeight = 120.0; // Even more compact since we don't need buttons
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: numberPadHeight + bottomPadding,
      ),
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: bottomPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hint.technique,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Hints remaining: ${gameLogic.hintsRemaining}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          for (int i = 0; i < 9; i++) {
                            for (int j = 0; j < 9; j++) {
                              gameLogic.relatedCells[i][j] = false;
                            }
                          }
                        });
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('Got it'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    hint.explanation,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
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

  void _handleHintRequest() {
    if (gameLogic.hintsRemaining > 0 && !isGameOver) {
      LogicalHint? hint = gameLogic.getLastLogicalHint();
      if (hint != null) {
        _showHintDialog(hint);
      } else {
        // No logical hint found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No logical next step found. Try using basic Sudoku techniques first.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Difficulty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: Difficulty.values.map((difficulty) => 
            ListTile(
              title: Text(
                difficulty.name[0].toUpperCase() + difficulty.name.substring(1),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                SudokuGameLogic(difficulty: difficulty).getDifficultyDescription(),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  resetGame(difficulty: difficulty);
                });
              },
            ),
          ).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'mintdoku',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: _showDifficultyDialog,
              child: Text(
                gameLogic.difficulty.name[0].toUpperCase() + 
                gameLogic.difficulty.name.substring(1),
                style: TextStyle(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isPaused ? Icons.play_arrow : Icons.pause,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: _togglePause,
            tooltip: isPaused ? 'Resume' : 'Pause',
          ),
          IconButton(
            icon: Icon(
              isNoteMode ? Icons.edit_off : Icons.edit,
              color: isNoteMode ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() {
                isNoteMode = !isNoteMode;
              });
            },
            tooltip: 'Toggle Note Mode',
          ),
          IconButton(
            icon: Icon(
              Icons.lightbulb_outline,
              color: gameLogic.hintsRemaining > 0 && !isGameOver 
                  ? theme.colorScheme.onSurface 
                  : theme.colorScheme.onSurface.withOpacity(0.38),
            ),
            onPressed: gameLogic.hintsRemaining > 0 && !isGameOver && !isPaused
                ? _handleHintRequest
                : null,
            tooltip: 'Get Hint (${gameLogic.hintsRemaining} remaining)',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: () => resetGame(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusItem(
                      icon: Icons.timer_outlined,
                      label: 'Time',
                      value: formattedTime,
                      theme: theme,
                    ),
                    _buildStatusItem(
                      icon: Icons.error_outline,
                      label: 'Faults',
                      value: '${gameLogic.faults}/${SudokuGameLogic.maxFaults}',
                      color: gameLogic.faults >= SudokuGameLogic.maxFaults
                          ? theme.colorScheme.error
                          : null,
                      theme: theme,
                    ),
                    _buildStatusItem(
                      icon: Icons.lightbulb_outline,
                      label: 'Hints',
                      value: '${gameLogic.hintsRemaining}',
                      theme: theme,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 600,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Sudoku Board
                          AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.outline,
                                  width: 2,
                                ),
                                color: theme.colorScheme.surface,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.shadowColor.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: List.generate(9, (row) {
                                  return Expanded(
                                    child: Row(
                                      children: List.generate(9, (col) {
                                        return Expanded(
                                          child: _buildCell(row, col),
                                        );
                                      }),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Number Pad
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 400,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    alignment: WrapAlignment.center,
                                    children: List.generate(9, (index) => _buildNumberButton(index + 1)),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: 200,
                                    child: FilledButton.tonal(
                                      onPressed: isGameOver ? null : clearCell,
                                      child: const Text('Clear'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isPaused)
            GestureDetector(
              onTap: _togglePause,
              child: Container(
                color: theme.colorScheme.surface.withOpacity(0.95),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pause_circle_outline,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Game Paused',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap anywhere to resume',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        formattedTime,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
    required ThemeData theme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color ?? theme.colorScheme.onSurface,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCell(int row, int col) {
    final theme = Theme.of(context);
    final isSelected = row == selectedRow && col == selectedCol;
    final isOriginalFixed = gameLogic.fixedNumbers[row][col];
    final isCorrectUserInput = !isOriginalFixed && 
        gameLogic.grid[row][col] != 0 && 
        gameLogic.grid[row][col] == gameLogic.solution[row][col];
    final isFixed = isOriginalFixed || isCorrectUserInput;
    final hasError = gameLogic.errorCells[row][col];
    final number = gameLogic.grid[row][col];
    final notes = gameLogic.notes[row][col];
    final selectedNumber = selectedRow != null && selectedCol != null ? 
        gameLogic.grid[selectedRow!][selectedCol!] : 
        null;
    
    return GestureDetector(
      onTap: () => selectCell(row, col),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              width: (col % 3 == 2 && col != 8) ? 2.0 : 0.5,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            bottom: BorderSide(
              width: (row % 3 == 2 && row != 8) ? 2.0 : 0.5,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            left: BorderSide(
              width: col == 0 ? 2.0 : 0,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            top: BorderSide(
              width: row == 0 ? 2.0 : 0,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
          color: _getCellColor(row, col, isSelected, hasError),
        ),
        child: number != 0
            ? Center(
                child: Text(
                  number.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    color: isOriginalFixed 
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.primary,
                    fontWeight: isFixed ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              )
            : notes.isEmpty
                ? Container()
                : GridView.count(
                    crossAxisCount: 3,
                    padding: const EdgeInsets.all(1),
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 0,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(9, (index) {
                      final noteNumber = index + 1;
                      final isHighlighted = selectedNumber != null && 
                          selectedNumber != 0 && 
                          noteNumber == selectedNumber;
                      return Center(
                        child: notes.contains(noteNumber)
                            ? FittedBox(
                                fit: BoxFit.contain,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 12,
                                    minHeight: 12,
                                  ),
                                  decoration: isHighlighted ? BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(2),
                                  ) : null,
                                  padding: const EdgeInsets.all(1),
                                  child: Text(
                                    noteNumber.toString(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isHighlighted
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withOpacity(0.5),
                                      fontWeight: isHighlighted 
                                          ? FontWeight.bold 
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              )
                            : Container(),
                      );
                    }),
                  ),
      ),
    );
  }

  Color _getCellColor(int row, int col, bool isSelected, bool hasError) {
    final theme = Theme.of(context);
    final number = gameLogic.grid[row][col];
    final selectedNumber = selectedRow != null && selectedCol != null ? 
        gameLogic.grid[selectedRow!][selectedCol!] : 
        null;

    if (hasError) {
      return theme.colorScheme.error.withOpacity(0.15);
    }
    if (isSelected) {
      return theme.colorScheme.primary.withOpacity(0.25);
    }
    if (selectedNumber != null && selectedNumber != 0 && number == selectedNumber) {
      return theme.colorScheme.primary.withOpacity(0.15);
    }
    if (gameLogic.relatedCells[row][col]) {
      return theme.colorScheme.secondary.withOpacity(0.15);
    }
    final blockRow = row ~/ 3;
    final blockCol = col ~/ 3;
    return (blockRow + blockCol) % 2 == 0
        ? theme.colorScheme.surfaceVariant.withOpacity(0.4)
        : theme.colorScheme.surface;
  }

  Widget _buildNumberButton(int number) {
    final theme = Theme.of(context);
    final remainingCount = gameLogic.getRemainingCount(number);
    final isComplete = gameLogic.isNumberComplete(number);

    if (isComplete) {
      return const SizedBox(width: 48, height: 48);
    }

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          FilledButton(
            onPressed: isGameOver
                ? null
                : () {
                    if (selectedRow != null && selectedCol != null) {
                      setState(() {
                        if (isNoteMode) {
                          gameLogic.toggleNote(selectedRow!, selectedCol!, number);
                          selectNumber(number); // Update highlights after toggling note
                        } else {
                          inputNumber(number);
                        }
                      });
                    } else {
                      selectNumber(number); // Highlight all instances when no cell is selected
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: isNoteMode 
                  ? theme.colorScheme.surfaceVariant 
                  : theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 20,
                color: isNoteMode 
                    ? theme.colorScheme.onSurfaceVariant 
                    : theme.colorScheme.onPrimary,
              ),
            ),
          ),
          if (remainingCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$remainingCount',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
      if (isPaused) {
        timer.cancel();
      } else {
        startTimer();
      }
    });
  }

  void resetGame({Difficulty? difficulty}) {
    setState(() {
      gameLogic = SudokuGameLogic(
        difficulty: difficulty ?? gameLogic.difficulty,
      );
      secondsElapsed = 0;
      isGameComplete = false;
      isGameOver = false;
      isPaused = false;
      selectedRow = null;
      selectedCol = null;
      timer.cancel();
      startTimer();
    });
  }
}
