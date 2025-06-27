import '../models/csat_question.dart';
import 'math_parser.dart';

class CSATParser {
  CSATQuestion parse(String text) {
    // TODO: implement more sophisticated parsing of CSAT-style problems.
    final lines = text.split('\n');
    int? number;
    if (lines.isNotEmpty) {
      final first = lines.first.trim();
      final numMatch = RegExp(r'^(\d+)').firstMatch(first);
      if (numMatch != null) {
        number = int.tryParse(numMatch.group(1)!);
      }
    }
    final body = lines.join('\n');
    final mathParser = MathParser();
    final formulas = mathParser.extractFormulas(text);
    return CSATQuestion(number: number, body: body, formulas: formulas);
  }
}
