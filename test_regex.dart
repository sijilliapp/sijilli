void main() {
  final String text = "[BOLD]﴿شَهْرُ رَمَضَانَ﴾[/BOLD] [آلِ عِمْرَانَ : ٧]";
  
  final cleanedText = text.replaceAllMapped(RegExp(r'\[([^\]]+?)\]'), (match) {
    final content = match.group(1)!;
    final cleanedContent = content
        .replaceAll('ٱ', 'ا')
        .replaceAll(RegExp(r'[\u064b-\u0652\u0670]'), '');
    return '[$cleanedContent]';
  });
  
  print('Result: $cleanedText');
}
