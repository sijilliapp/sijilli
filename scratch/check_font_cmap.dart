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
  
  // Let's check a few Presentation Forms code points:
  // 0xFE8D (Alef isolated), 0xFE91 (Beh initial), 0xFEE1 (Meem isolated)
  final testChars = [0x0627, 0x0628, 0x0645, 0xFE8D, 0xFE91, 0xFEE1];
  for (final char in testChars) {
    final glyphIndex = parser.charToGlyphIndexMap[char];
    print('Char: 0x${char.toRadixString(16).toUpperCase()} -> Glyph Index: $glyphIndex');
  }
}
