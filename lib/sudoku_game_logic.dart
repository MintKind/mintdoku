// Define difficulty levels
enum Difficulty {
  easy,
  medium,
  hard,
  expert, insane
}

// Represents a logical hint with explanation
class LogicalHint {
  final int row;
  final int col;
  final int number;
  final String explanation;
  final String technique;

  LogicalHint(this.row, this.col, this.number, this.explanation, this.technique);
}

class SudokuGameLogic {
  late List<List<int>> grid;
  late List<List<bool>> fixedNumbers;
  late List<List<bool>> errorCells;
  late List<List<bool>> relatedCells;
  late List<List<Set<int>>> notes; // Store notes for each cell
  late List<List<int>> solution;
  late Map<int, int> remainingNumbers; // Track remaining count for each number
  Difficulty difficulty;
  int faults = 0;
  late int hintsRemaining;
  static const int maxFaults = 3;

  // Configure difficulty settings
  static const Map<Difficulty, ({int cellsToRemove, int hints})> difficultySettings = {
    Difficulty.easy: (cellsToRemove: 35, hints: 5),
    Difficulty.medium: (cellsToRemove: 45, hints: 3),
    Difficulty.hard: (cellsToRemove: 55, hints: 3),
    Difficulty.expert: (cellsToRemove: 62, hints: 3),
    Difficulty.insane: (cellsToRemove: 70, hints: 5),
  };

  SudokuGameLogic({this.difficulty = Difficulty.medium}) {
    grid = List.generate(9, (_) => List.filled(9, 0));
    fixedNumbers = List.generate(9, (_) => List.filled(9, false));
    errorCells = List.generate(9, (_) => List.filled(9, false));
    relatedCells = List.generate(9, (_) => List.filled(9, false));
    notes = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
    solution = List.generate(9, (_) => List.filled(9, 0));
    remainingNumbers = {};
    hintsRemaining = difficultySettings[difficulty]!.hints;
    generatePuzzle();
  }

  // Check if a number is valid according to Sudoku rules
  bool isValidForSudoku(int row, int col, int number) {
    // Check row
    for (int x = 0; x < 9; x++) {
      if (grid[row][x] == number) return false;
    }

    // Check column
    for (int x = 0; x < 9; x++) {
      if (grid[x][col] == number) return false;
    }

    // Check 3x3 box
    int boxRow = row - row % 3;
    int boxCol = col - col % 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (grid[boxRow + i][boxCol + j] == number) return false;
      }
    }

    return true;
  }

  // Check if a move matches the solution during gameplay
  bool isValidMove(int row, int col, int number) {
    return number == solution[row][col];
  }

  bool isComplete() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (grid[i][j] == 0 || grid[i][j] != solution[i][j]) {
          return false;
        }
      }
    }
    return true;
  }

  bool hasErrors() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (errorCells[i][j]) return true;
      }
    }
    return false;
  }

  void checkForErrors() {
    // Clear previous errors
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        errorCells[i][j] = false;
      }
    }

    // Check for errors against the solution
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (grid[i][j] != 0 && grid[i][j] != solution[i][j]) {
          errorCells[i][j] = true;
        }
      }
    }
  }

  void markConflictingCells(int row, int col, int number) {
    // Mark row
    for (int i = 0; i < 9; i++) {
      if (grid[row][i] == number && i != col) {
        errorCells[row][i] = true;
      }
    }

    // Mark column
    for (int i = 0; i < 9; i++) {
      if (grid[i][col] == number && i != row) {
        errorCells[i][col] = true;
      }
    }

    // Mark 3x3 box
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int i = boxRow; i < boxRow + 3; i++) {
      for (int j = boxCol; j < boxCol + 3; j++) {
        if (grid[i][j] == number && (i != row || j != col)) {
          errorCells[i][j] = true;
        }
      }
    }
  }

  void generatePuzzle() {
    // Clear the grid
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        grid[i][j] = 0;
        fixedNumbers[i][j] = false;
      }
    }

    // Fill diagonal box first
    fillDiagonalBox(0, 0);
    
    // Solve the entire puzzle
    solveSudoku();
    
    // Store the solution
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        solution[i][j] = grid[i][j];
        fixedNumbers[i][j] = true;
      }
    }
    
    // Remove numbers based on difficulty
    removeNumbers(difficultySettings[difficulty]!.cellsToRemove);
    
    // Initialize remaining numbers count
    _updateRemainingNumbers();
  }

  void fillDiagonalBox(int startRow, int startCol) {
    List<int> numbers = List.generate(9, (index) => index + 1)..shuffle();
    int index = 0;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        grid[startRow + i][startCol + j] = numbers[index++];
      }
    }
  }

  bool solveSudoku() {
    int row = -1;
    int col = -1;
    bool isEmpty = false;
    
    // Find an empty cell
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (grid[i][j] == 0) {
          row = i;
          col = j;
          isEmpty = true;
          break;
        }
      }
      if (isEmpty) {
        break;
      }
    }
    
    // No empty cell found, puzzle is solved
    if (!isEmpty) {
      return true;
    }
    
    // Try digits 1 to 9
    for (int num = 1; num <= 9; num++) {
      if (isValidForSudoku(row, col, num)) {
        grid[row][col] = num;
        if (solveSudoku()) {
          return true;
        }
        grid[row][col] = 0; // backtrack
      }
    }
    return false;
  }

  void removeNumbers(int count) {
    List<int> positions = List.generate(81, (index) => index)..shuffle();
    for (int i = 0; i < count && i < positions.length; i++) {
      int pos = positions[i];
      int row = pos ~/ 9;
      int col = pos % 9;
      grid[row][col] = 0;
      fixedNumbers[row][col] = false;
    }
  }

  bool canEditCell(int row, int col) {
    return !fixedNumbers[row][col];
  }

  void setCell(int row, int col, int number) {
    if (canEditCell(row, col)) {
      int previousNumber = grid[row][col];
      grid[row][col] = number;
      checkForErrors();
      
      if (errorCells[row][col]) {
        faults++;
      } else {
        // Update remaining numbers count
        if (previousNumber != 0) {
          remainingNumbers[previousNumber] = remainingNumbers[previousNumber]! + 1;
        }
        remainingNumbers[number] = remainingNumbers[number]! - 1;
        
        // If the move was valid, update notes
        updateNotesAfterMove(row, col, number);
      }
    }
  }

  void clearCell(int row, int col) {
    if (canEditCell(row, col)) {
      int previousNumber = grid[row][col];
      if (previousNumber != 0) {
        remainingNumbers[previousNumber] = remainingNumbers[previousNumber]! + 1;
      }
      grid[row][col] = 0;
      checkForErrors();
    }
  }

  bool isGameOver() {
    return faults >= maxFaults;
  }

  void updateRelatedCells(int? selectedRow, int? selectedCol) {
    // Clear previous related cells
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        relatedCells[i][j] = false;
      }
    }

    // If no cell is selected or the selected cell is empty, return
    if (selectedRow == null || selectedCol == null || grid[selectedRow][selectedCol] == 0) {
      return;
    }

    int selectedNumber = grid[selectedRow][selectedCol];

    // Mark all cells with the same number
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (grid[i][j] == selectedNumber) {
          relatedCells[i][j] = true;
        }
      }
    }
  }

  // Check if a number is possible in a cell according to current grid state
  bool isNumberPossible(int row, int col, int number) {
    if (grid[row][col] != 0) return false;

    // Check row
    for (int x = 0; x < 9; x++) {
      if (grid[row][x] == number) return false;
    }

    // Check column
    for (int x = 0; x < 9; x++) {
      if (grid[x][col] == number) return false;
    }

    // Check 3x3 box
    int boxRow = row - row % 3;
    int boxCol = col - col % 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (grid[boxRow + i][boxCol + j] == number) return false;
      }
    }

    return true;
  }

  // Toggle a note in a cell
  void toggleNote(int row, int col, int number) {
    if (!fixedNumbers[row][col] && grid[row][col] == 0) {
      if (isNumberPossible(row, col, number)) {
        if (notes[row][col].contains(number)) {
          notes[row][col].remove(number);
        } else {
          notes[row][col].add(number);
        }
      }
    }
  }

  // Clear all notes in a cell
  void clearNotes(int row, int col) {
    notes[row][col].clear();
  }

  // Get valid possibilities for a cell
  Set<int> getValidPossibilities(int row, int col) {
    Set<int> possibilities = {};
    if (!fixedNumbers[row][col] && grid[row][col] == 0) {
      for (int num = 1; num <= 9; num++) {
        if (isNumberPossible(row, col, num)) {
          possibilities.add(num);
        }
      }
    }
    return possibilities;
  }

  // Update notes when a number is placed
  void updateNotesAfterMove(int row, int col, int number) {
    // Clear notes in the affected cell
    clearNotes(row, col);

    // Remove the number from notes in the same row
    for (int j = 0; j < 9; j++) {
      notes[row][j].remove(number);
    }

    // Remove the number from notes in the same column
    for (int i = 0; i < 9; i++) {
      notes[i][col].remove(number);
    }

    // Remove the number from notes in the same 3x3 box
    int boxRow = row - row % 3;
    int boxCol = col - col % 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        notes[boxRow + i][boxCol + j].remove(number);
      }
    }
  }

  // Get a hint for the selected cell
  bool getHint(int row, int col) {
    if (hintsRemaining > 0 && !fixedNumbers[row][col] && grid[row][col] != solution[row][col]) {
      grid[row][col] = solution[row][col];
      // Don't mark hint numbers as fixed
      updateNotesAfterMove(row, col, grid[row][col]);
      hintsRemaining--;
      return true;
    }
    return false;
  }

  // Get a hint for any empty or incorrect cell
  ({int row, int col})? getRandomHint() {
    if (hintsRemaining <= 0) return null;

    List<({int row, int col})> availableCells = [];
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (!fixedNumbers[i][j] && grid[i][j] != solution[i][j]) {
          availableCells.add((row: i, col: j));
        }
      }
    }

    if (availableCells.isEmpty) return null;

    availableCells.shuffle();
    var cell = availableCells.first;
    if (getHint(cell.row, cell.col)) {
      return cell;
    }
    return null;
  }

  // Find the next logical step
  LogicalHint? findLogicalHint() {
    if (hintsRemaining <= 0) return null;

    // Try different solving techniques in order of difficulty
    LogicalHint? hint;
    
    // 1. Single Candidate (Naked Single)
    hint = findSingleCandidate();
    if (hint != null) return hint;

    // 2. Hidden Single in Row
    hint = findHiddenSingle("row");
    if (hint != null) return hint;

    // 3. Hidden Single in Column
    hint = findHiddenSingle("column");
    if (hint != null) return hint;

    // 4. Hidden Single in Box
    hint = findHiddenSingle("box");
    if (hint != null) return hint;

    return null;
  }

  // Find a cell where only one number is possible
  LogicalHint? findSingleCandidate() {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          Set<int> possibilities = getValidPossibilities(row, col);
          if (possibilities.length == 1) {
            int number = possibilities.first;
            return LogicalHint(
              row,
              col,
              number,
              'This cell can only be $number because all other numbers (1-9) would conflict with existing numbers in the same row, column, or 3x3 box.',
              'Single Candidate'
            );
          }
        }
      }
    }
    return null;
  }

  // Find a number that can only go in one place in a row, column, or box
  LogicalHint? findHiddenSingle(String type) {
    for (int i = 0; i < 9; i++) {
      for (int number = 1; number <= 9; number++) {
        List<(int, int)> possiblePositions = [];
        
        // Check all cells in the current unit (row/column/box)
        for (int j = 0; j < 9; j++) {
          int row, col;
          if (type == "row") {
            row = i;
            col = j;
          } else if (type == "column") {
            row = j;
            col = i;
          } else { // box
            row = (i ~/ 3) * 3 + j ~/ 3;
            col = (i % 3) * 3 + j % 3;
          }

          if (grid[row][col] == 0 && isNumberPossible(row, col, number)) {
            possiblePositions.add((row, col));
          }
        }

        // If number can only go in one place
        if (possiblePositions.length == 1) {
          var pos = possiblePositions.first;
          String unitDescription = type == "box" 
              ? '3x3 box'
              : type;
          return LogicalHint(
            pos.$1,
            pos.$2,
            number,
            'The number $number can only go in this cell because it\'s the only position available in this $unitDescription.',
            'Hidden Single in ${type[0].toUpperCase() + type.substring(1)}'
          );
        }
      }
    }
    return null;
  }

  // Use a logical hint
  bool useLogicalHint() {
    if (hintsRemaining <= 0) return false;

    LogicalHint? hint = findLogicalHint();
    if (hint != null) {
      grid[hint.row][hint.col] = hint.number;
      // Don't mark hint numbers as fixed
      updateNotesAfterMove(hint.row, hint.col, hint.number);
      hintsRemaining--;
      return true;
    }
    
    // If no logical hint found, fall back to revealing a solution cell
    var randomCell = getRandomHint();
    return randomCell != null;
  }

  // Get the last hint's explanation
  LogicalHint? getLastLogicalHint() {
    return findLogicalHint();
  }

  // Get difficulty description
  String getDifficultyDescription() {
    switch (difficulty) {
      case Difficulty.easy:
        return 'Easy - More starting numbers and hints. Perfect for beginners.';
      case Difficulty.medium:
        return 'Medium - Balanced challenge with moderate hints.';
      case Difficulty.hard:
        return 'Hard - Fewer starting numbers and hints. For experienced players.';
      case Difficulty.expert:
        return 'Expert - Minimal starting numbers and hints. True Sudoku mastery required!';
      case Difficulty.insane:
        return 'Insane - Minimal starting numbers and hints. True Sudoku mastery required!';
    }
  }

  // Update the count of remaining numbers
  void _updateRemainingNumbers() {
    // Initialize counts for each number (1-9)
    remainingNumbers = {
      for (int i = 1; i <= 9; i++) i: 9
    };

    // Count numbers in the grid
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (grid[i][j] != 0) {
          remainingNumbers[grid[i][j]] = remainingNumbers[grid[i][j]]! - 1;
        }
      }
    }
  }

  // Get the remaining count for a number
  int getRemainingCount(int number) {
    return remainingNumbers[number] ?? 0;
  }

  // Check if a number is completely placed
  bool isNumberComplete(int number) {
    return remainingNumbers[number] == 0;
  }
} 