/// Pure-Dart matrix operations needed for OLS and Huber regression.
/// All matrices are represented as List<List<double>> (row-major).
class MatrixMath {
  /// Matrix multiplication: A (m×k) × B (k×n) → C (m×n)
  static List<List<double>> multiply(List<List<double>> a, List<List<double>> b) {
    final m = a.length;
    final k = a[0].length;
    final n = b[0].length;
    assert(k == b.length, 'Incompatible dimensions for multiply');

    final c = List.generate(m, (_) => List.filled(n, 0.0));
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        double sum = 0.0;
        for (int l = 0; l < k; l++) {
          sum += a[i][l] * b[l][j];
        }
        c[i][j] = sum;
      }
    }
    return c;
  }

  /// Transpose: A (m×n) → Aᵀ (n×m)
  static List<List<double>> transpose(List<List<double>> a) {
    final m = a.length;
    final n = a[0].length;
    final t = List.generate(n, (_) => List.filled(m, 0.0));
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        t[j][i] = a[i][j];
      }
    }
    return t;
  }

  /// Invert a square matrix via Gauss-Jordan elimination.
  /// Returns null if matrix is singular.
  static List<List<double>>? invert(List<List<double>> a) {
    final n = a.length;
    // Augment [a | I]
    final aug = List.generate(n, (i) {
      final row = List<double>.from(a[i]);
      for (int j = 0; j < n; j++) {
        row.add(i == j ? 1.0 : 0.0);
      }
      return row;
    });

    for (int col = 0; col < n; col++) {
      // Find pivot
      int pivot = col;
      for (int row = col + 1; row < n; row++) {
        if (aug[row][col].abs() > aug[pivot][col].abs()) pivot = row;
      }
      final tmp = aug[col];
      aug[col] = aug[pivot];
      aug[pivot] = tmp;

      if (aug[col][col].abs() < 1e-12) return null; // singular

      final scale = aug[col][col];
      for (int j = 0; j < 2 * n; j++) {
        aug[col][j] /= scale;
      }

      for (int row = 0; row < n; row++) {
        if (row == col) continue;
        final factor = aug[row][col];
        for (int j = 0; j < 2 * n; j++) {
          aug[row][j] -= factor * aug[col][j];
        }
      }
    }

    return List.generate(n, (i) => aug[i].sublist(n));
  }

  /// Multiply matrix A by column vector v: result is column vector (as List<double>).
  static List<double> multiplyVec(List<List<double>> a, List<double> v) {
    final m = a.length;
    final result = List.filled(m, 0.0);
    for (int i = 0; i < m; i++) {
      double sum = 0.0;
      for (int j = 0; j < v.length; j++) {
        sum += a[i][j] * v[j];
      }
      result[i] = sum;
    }
    return result;
  }

  /// Wrap a column vector as an n×1 matrix.
  static List<List<double>> colVec(List<double> v) =>
      List.generate(v.length, (i) => [v[i]]);

  /// Flatten an n×1 or 1×n matrix to a List<double>.
  static List<double> flatten(List<List<double>> m) {
    if (m[0].length == 1) return m.map((r) => r[0]).toList();
    return m[0];
  }
}
