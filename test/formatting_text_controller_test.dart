import 'package:flutter_test/flutter_test.dart';
import 'package:sijilli/features/articles/widgets/formatting_text_controller.dart';
import 'package:sijilli/models/article.dart';
import 'package:flutter/material.dart';

void main() {
  group('Article Strip Formatting Tests', () {
    test('Should strip simple tags and formatting characters', () {
      const raw = 'هذا [BOLD]نص عريض[/BOLD] و[HIGHLIGHT]نص ملون[/HIGHLIGHT]';
      final clean = Article.stripFormatting(raw);
      expect(clean, equals('هذا نص عريض ونص ملون'));
    });

    test('Should parse poetry and merge sadr and ajez with ***', () {
      const raw = '[POEM]\n'
          'أنا ابن جلا وطلاع الثنايا\n'
          'متى أضع العمامة تعرفوني\n'
          'فغض الطرف إنك من نمير\n'
          'فلا كعباً بلغت ولا كلاباً\n'
          '[/POEM]';
      
      final clean = Article.stripFormatting(raw);
      expect(
        clean,
        equals(
          'أنا ابن جلا وطلاع الثنايا *** متى أضع العمامة تعرفوني\n'
          'فغض الطرف إنك من نمير *** فلا كعباً بلغت ولا كلاباً'
        ),
      );
    });

    test('Should respect centered lines inside poem block as standalone lines', () {
      const raw = '[POEM]\n'
          '= ثم قال الشاعر =\n'
          'أنا ابن جلا وطلاع الثنايا\n'
          'متى أضع العمامة تعرفوني\n'
          '[/POEM]';
      
      final clean = Article.stripFormatting(raw);
      expect(
        clean,
        equals(
          'ثم قال الشاعر\n'
          'أنا ابن جلا وطلاع الثنايا *** متى أضع العمامة تعرفوني'
        ),
      );
    });
  });

  group('FormattingTextEditingController Tests', () {
    test('setRawText and rawText roundtrip', () {
      const rawInput = 'مرحبًا بك في [BOLD]سجلي[/BOLD] التطبيق الرائع.\n'
          '[CENTER]هذا سطر موسط[/CENTER]\n'
          'وهنا [HIGHLIGHT]تظليل جميل[/HIGHLIGHT].';

      final controller = FormattingTextEditingController(rawText: rawInput);

      expect(controller.cleanText, equals('مرحبًا بك في سجلي التطبيق الرائع.\nهذا سطر موسط\nوهنا تظليل جميل.'));
      expect(controller.spans.length, equals(2));
      expect(controller.spans[0].type, equals(SpanType.bold));
      expect(controller.spans[1].type, equals(SpanType.highlight));

      expect(controller.lineFormats[0], equals(ParagraphFormat.none));
      expect(controller.lineFormats[1], equals(ParagraphFormat.center));
      expect(controller.lineFormats[2], equals(ParagraphFormat.none));

      // Check roundtrip serialization matches rawInput
      expect(controller.rawText, equals(rawInput));
    });

    test('toggleBoldAtCursor on word boundary with collapsed selection', () {
      final controller = FormattingTextEditingController(rawText: 'هذا نص تجريبي رائع');
      
      // Put cursor inside the word 'تجريبي' (indices 8 to 14)
      controller.selection = const TextSelection.collapsed(offset: 11);
      
      controller.toggleBoldAtCursor();
      
      expect(controller.spans.length, equals(1));
      expect(controller.spans[0].type, equals(SpanType.bold));
      expect(controller.spans[0].start, equals(7));
      expect(controller.spans[0].end, equals(13)); // 'تجريبي'
      
      // Untoggle bold
      controller.toggleBoldAtCursor();
      expect(controller.spans.isEmpty, isTrue);
    });

    test('toggleParagraphFormat toggles center alignment', () {
      final controller = FormattingTextEditingController(rawText: 'السطر الأول\nالسطر الثاني\nالسطر الثالث');
      
      // Select inside second line
      controller.selection = const TextSelection.collapsed(offset: 15);
      
      controller.toggleParagraphFormat(ParagraphFormat.center);
      
      expect(controller.lineFormats[0], equals(ParagraphFormat.none));
      expect(controller.lineFormats[1], equals(ParagraphFormat.center));
      expect(controller.lineFormats[2], equals(ParagraphFormat.none));
      
      // Serialize should wrap second line in [CENTER]
      expect(
        controller.rawText,
        equals('السطر الأول\n[CENTER]السطر الثاني[/CENTER]\nالسطر الثالث'),
      );
    });

    test('Smart Poetry Formatting on selection splits text by ***', () {
      final controller = FormattingTextEditingController(rawText: 'شعر مبدئي\n');
      
      // Place selection at the end
      controller.selection = const TextSelection.collapsed(offset: 10);
      
      // Simulate paste of poetry with *** (should paste as normal text)
      const pastedText = 'سأضحك يا سماء فلا تغيمي *** سأهزأ بالرعود القاصفات';
      controller.value = TextEditingValue(
        text: 'شعر مبدئي\n$pastedText',
        selection: const TextSelection(baseOffset: 10, extentOffset: 10 + pastedText.length),
      );

      // Verify that on paste, it did NOT automatically split into poem format
      expect(controller.cleanText, equals('شعر مبدئي\nسأضحك يا سماء فلا تغيمي *** سأهزأ بالرعود القاصفات'));
      expect(controller.lineFormats[1], equals(ParagraphFormat.none));

      // Now, simulate the user explicitly clicking the poem formatting button on the selection
      controller.toggleParagraphFormat(ParagraphFormat.poem);

      // Now it should split into Sadr and Ajez lines and assign ParagraphFormat.poem to both
      expect(controller.cleanText, equals('شعر مبدئي\nسأضحك يا سماء فلا تغيمي\nسأهزأ بالرعود القاصفات'));
      expect(controller.lineFormats[1], equals(ParagraphFormat.poem));
      expect(controller.lineFormats[2], equals(ParagraphFormat.poem));
    });

    test('Prevent overlapping bold and highlight', () {
      final controller = FormattingTextEditingController(rawText: 'هذا نص تجريبي رائع');
      
      // Select 'تجريبي' (indices 7 to 13)
      controller.selection = const TextSelection(baseOffset: 7, extentOffset: 13);
      
      // Apply Bold
      controller.toggleBoldAtCursor();
      expect(controller.spans.length, equals(1));
      expect(controller.spans[0].type, equals(SpanType.bold));
      
      // Try to apply Highlight to same range - should be blocked
      controller.toggleHighlightAtCursor();
      expect(controller.spans.length, equals(1)); // Still only 1 span (bold)
      expect(controller.spans[0].type, equals(SpanType.bold));
      
      // Untoggle Bold
      controller.toggleBoldAtCursor();
      expect(controller.spans.isEmpty, isTrue);
      
      // Apply Highlight
      controller.toggleHighlightAtCursor();
      expect(controller.spans.length, equals(1));
      expect(controller.spans[0].type, equals(SpanType.highlight));
      
      // Try to apply Bold to same range - should be blocked
      controller.toggleBoldAtCursor();
      expect(controller.spans.length, equals(1)); // Still only 1 span (highlight)
      expect(controller.spans[0].type, equals(SpanType.highlight));
    });

    test('Toggle off poem formats restores their standard alignments', () {
      final controller = FormattingTextEditingController(
        rawText: '[POEM]\n'
            'هذا سطر شعر عادي\n'
            '= هذا سطر شعر موسط =\n'
            '[LEFT]هذا سطر شعر يسار[/LEFT]\n'
            '[/POEM]'
      );

      // Line 0 is poem, line 1 is poemCenter, line 2 is poemLeft
      expect(controller.lineFormats[0], equals(ParagraphFormat.poem));
      expect(controller.lineFormats[1], equals(ParagraphFormat.poemCenter));
      expect(controller.lineFormats[2], equals(ParagraphFormat.poemLeft));

      // 1. Put cursor in Line 0 (offset 5) and toggle poem -> should become ParagraphFormat.none
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.toggleParagraphFormat(ParagraphFormat.poem);
      expect(controller.lineFormats[0], equals(ParagraphFormat.none));

      // 2. Put cursor in Line 1 (offset 25) and toggle poem -> should become ParagraphFormat.center
      controller.selection = const TextSelection.collapsed(offset: 25);
      controller.toggleParagraphFormat(ParagraphFormat.poem);
      expect(controller.lineFormats[1], equals(ParagraphFormat.center));

      // 3. Put cursor in Line 2 (offset 40) and toggle poem -> should become ParagraphFormat.left
      controller.selection = const TextSelection.collapsed(offset: 40);
      controller.toggleParagraphFormat(ParagraphFormat.poem);
      expect(controller.lineFormats[2], equals(ParagraphFormat.left));

      // Roundtrip check:
      expect(
        controller.rawText,
        equals('هذا سطر شعر عادي\n[CENTER] هذا سطر شعر موسط [/CENTER]\n[LEFT]هذا سطر شعر يسار[/LEFT]'),
      );
    });

    test('Toggle alignment on poem line changes sub-alignment without removing poem format', () {
      final controller = FormattingTextEditingController(
        rawText: '[POEM]\nهذا شطر عادي\n[/POEM]'
      );
      expect(controller.lineFormats[0], equals(ParagraphFormat.poem));

      // Put cursor inside the poem line
      controller.selection = const TextSelection.collapsed(offset: 5);

      // Toggle center alignment -> should become poemCenter
      controller.toggleParagraphFormat(ParagraphFormat.center);
      expect(controller.lineFormats[0], equals(ParagraphFormat.poemCenter));
      expect(controller.rawText, equals('[POEM]\n[CENTER]هذا شطر عادي[/CENTER]\n[/POEM]'));

      // Toggle center alignment again -> should become poem
      controller.toggleParagraphFormat(ParagraphFormat.center);
      expect(controller.lineFormats[0], equals(ParagraphFormat.poem));
      expect(controller.rawText, equals('[POEM]\nهذا شطر عادي\n[/POEM]'));
    });

    test('Undo and Redo should restore spans and paragraph formats', () {
      final controller = FormattingTextEditingController(rawText: 'هذا سطر عادي');
      
      // 1. Bold the text
      controller.selection = const TextSelection(baseOffset: 4, extentOffset: 8);
      controller.toggleBoldAtCursor();
      expect(controller.spans.length, equals(1));
      expect(controller.spans[0].type, equals(SpanType.bold));

      // 2. Clear formatting
      controller.setRawText('هذا سطر عادي');
      expect(controller.spans.isEmpty, isTrue);

      // 3. Undo -> should restore the bold formatting!
      controller.undo();
      expect(controller.spans.length, equals(1));
      expect(controller.spans[0].type, equals(SpanType.bold));

      // 4. Redo -> should clear formatting again!
      controller.redo();
      expect(controller.spans.isEmpty, isTrue);
    });

    test('Pasting normal text with tabs or consecutive spaces should NOT trigger poem format', () {
      final controller = FormattingTextEditingController(rawText: 'موضوع عادي\n');
      
      // Place selection at the end
      controller.selection = const TextSelection.collapsed(offset: 11);
      
      // Simulate paste of text containing tabs and consecutive spaces
      const pastedText = 'هذا نص عادي يحتوي على\tعلامة جدولة و   ثلاث مسافات';
      controller.value = TextEditingValue(
        text: 'موضوع عادي\n$pastedText',
        selection: const TextSelection.collapsed(offset: 11 + pastedText.length),
      );

      // It should paste the text as is without formatting it as a poem
      expect(controller.cleanText, equals('موضوع عادي\nهذا نص عادي يحتوي على\tعلامة جدولة و   ثلاث مسافات'));
      expect(controller.lineFormats[0], equals(ParagraphFormat.none));
      expect(controller.lineFormats[1], equals(ParagraphFormat.none));
    });

    test('Pasting text should select/highlight the pasted range', () {
      final controller = FormattingTextEditingController(rawText: 'موضوع عادي\n');
      controller.selection = const TextSelection.collapsed(offset: 11);

      const pastedText = 'هذا النص تم لصقه للتو';
      controller.value = TextEditingValue(
        text: 'موضوع عادي\n$pastedText',
        selection: const TextSelection.collapsed(offset: 11 + pastedText.length),
      );

      // The selection should NOT be collapsed at the end, it should highlight the pasted text range!
      expect(controller.selection.start, equals(11));
      expect(controller.selection.end, equals(11 + pastedText.length));
    });

    test('Pressing Enter at the start of a formatted line shifts format down and keeps new line none', () {
      final controller = FormattingTextEditingController(rawText: 'شعر أول\nشعر ثان');
      
      // Select all and toggle poem format
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 15);
      controller.toggleParagraphFormat(ParagraphFormat.poem);
      expect(controller.lineFormats[0], equals(ParagraphFormat.poem));
      expect(controller.lineFormats[1], equals(ParagraphFormat.poem));
      
      // Move selection to index 0 (start of first line)
      controller.selection = const TextSelection.collapsed(offset: 0);
      
      // Type a newline (simulate pressing Enter)
      controller.value = const TextEditingValue(
        text: '\nشعر أول\nشعر ثان',
        selection: TextSelection.collapsed(offset: 1),
      );

      // Now Line 0 (new empty line) should be none, Line 1 ("شعر أول") should be poem, Line 2 ("شعر ثان") should be poem
      expect(controller.lineFormats[0], equals(ParagraphFormat.none));
      expect(controller.lineFormats[1], equals(ParagraphFormat.poem));
      expect(controller.lineFormats[2], equals(ParagraphFormat.poem));
    });
  });
}
