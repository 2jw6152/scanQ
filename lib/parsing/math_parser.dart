class MathParser {
  /// Extracts potential formulas from the given [text].
  ///
  /// A formula is considered any line containing digits and a mathematical
  /// operator such as +, -, ×, x, *, /, ^, =, <, or >. Fractions using `/`
  /// or `÷` are also detected. Parentheses may surround variables or digits.
  List<String> extractFormulas(String text) {
    final List<String> formulas = [];
    final lines = text.split('\n');
    final regex = RegExp(
      r'[\w\d()]+(?:\s*[+\-x×*÷/=^<>]\s*[\w\d()]+)+',
    );
    for (final line in lines) {
      final matches = regex.allMatches(line);
      for (final match in matches) {
        final formula = match.group(0);
        if (formula != null && formula.trim().isNotEmpty) {
          formulas.add(formula.trim());
        }
      }
    }
    return formulas;
  }
}