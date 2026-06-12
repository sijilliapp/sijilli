import 'package:pdf/src/pdf/font/arabic.dart' as pdf_arabic;

void main() {
  const original = 'باليوم العالمي للغة العربية';
  final converted = pdf_arabic.convert(original);
  print('Original: $original');
  print('Converted: $converted');
  print('Original codeUnits: ${original.codeUnits}');
  print('Converted codeUnits: ${converted.codeUnits}');
}
