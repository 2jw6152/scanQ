import 'package:flutter_test/flutter_test.dart';
import 'package:scanq/parsing/math_parser.dart';

void main() {
  test('sample test', () {
    expect(1 + 1, equals(2));
  });

  test('math parser extracts formulas', () {
    const text = '1 + 2 = 3\n다음 중 x^2 + 3x + 2 = 0 의 해를 고르시오';
    final parser = MathParser();
    final formulas = parser.extractFormulas(text);
    expect(formulas, contains('1 + 2 = 3'));
    expect(formulas.any((f) => f.contains('x^2')), isTrue);
  });
}
