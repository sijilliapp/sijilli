import 'dart:io';
import 'package:pdf/src/pdf/font/ttf_parser.dart';

void main() {
  final file = File('/Users/hussain/Documents/sijilli/assets/fonts/Manal_High.ttf');
  if (!file.existsSync()) {
    print('Font not found!');
    return;
  }
  
  final bytes = file.readAsBytesSync();
  final parser = TtfParser(bytes.buffer.asByteData());
  
  // Check different shapes of Beh (ب):
  // 0x0628: basic Beh
  // 0xFE8F: isolated Beh
  // 0xFE90: final Beh
  // 0xFE91: initial Beh
  // 0xFE92: medial Beh
  final behShapes = {
    'basic': 0x0628,
    'isolated': 0xFE8F,
    'final': 0xFE90,
    'initial': 0xFE91,
    'medial': 0xFE92,
  };
  
  for (final entry in behShapes.entries) {
    final glyphIndex = parser.charToGlyphIndexMap[entry.value];
    print('Beh ${entry.key} (0x${entry.value.toRadixString(16).toUpperCase()}) -> Glyph Index: $glyphIndex');
  }
}
