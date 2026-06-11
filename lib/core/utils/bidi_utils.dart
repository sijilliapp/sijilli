import 'package:flutter/material.dart';

class BidiUtils {
  BidiUtils._();

  /// Resolves the text direction of a string based on its first strong character.
  /// If no strong characters are found or the text is empty, it falls back to
  /// the specified fallback direction (defaults to LTR).
  static TextDirection getDirection(String text, {TextDirection? fallback}) {
    if (text.isEmpty) {
      return fallback ?? TextDirection.ltr;
    }

    // Regular expression matching the first character with strong directionality:
    // Group 1 matches LTR letters: Latin alphabet [a-zA-Z].
    // Group 2 matches RTL letters: Standard Arabic Unicode ranges.
    final regex = RegExp(
      r'([a-zA-Z])|([\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF])',
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      if (match.group(2) != null) {
        return TextDirection.rtl; // Arabic/RTL character found first
      } else if (match.group(1) != null) {
        return TextDirection.ltr; // Latin/LTR character found first
      }
    }

    return fallback ?? TextDirection.ltr;
  }

  /// Helper to check if a text should be rendered in Right-to-Left (RTL) direction.
  static bool isRtl(String text, {bool fallbackToRtl = false}) {
    return getDirection(text, fallback: fallbackToRtl ? TextDirection.rtl : TextDirection.ltr) == TextDirection.rtl;
  }
}
