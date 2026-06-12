import 'package:pdf/src/pdf/font/bidi_utils.dart' as bidi;

void main() {
  const original = 'باليوم العالمي للغة العربية';
  final result = bidi.logicalToVisual(original);
  print('Original: $original');
  print('Result: $result');
  print('Result codeUnits: ${result.codeUnits}');
}
