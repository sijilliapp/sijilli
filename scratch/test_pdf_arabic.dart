import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/src/pdf/font/arabic.dart' as pdf_arabic;

void main() async {
  final pdf = pw.Document();
  
  // Try to load a font that supports Arabic
  // We can use NotoSansArabic from the assets folder since we know it exists.
  final fontData = File('/Users/hussain/Documents/sijilli/assets/fonts/Manal_High.ttf').readAsBytesSync();
  final font = pw.Font.ttf(fontData.buffer.asByteData());
  
  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        final originalText = 'باليوم العالمي للغة العربية';
        final shapedText = pdf_arabic.convert(originalText);
        
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Method 1 (Standard):',
              style: pw.TextStyle(font: font, fontSize: 20),
            ),
            pw.Text(
              originalText,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 24),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Method 2 (Pre-shaped LTR):',
              style: pw.TextStyle(font: font, fontSize: 20),
            ),
            pw.Text(
              shapedText,
              textDirection: pw.TextDirection.ltr,
              style: pw.TextStyle(font: font, fontSize: 24),
            ),
          ],
        );
      },
    ),
  );

  final file = File('/Users/hussain/Documents/sijilli/scratch/arabic_shaping_test.pdf');
  await file.writeAsBytes(await pdf.save());
  print('Saved PDF to: ${file.path}');
}
