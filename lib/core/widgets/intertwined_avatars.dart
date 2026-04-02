import 'package:flutter/material.dart';
// Reuse for individual avatar logic if needed, or simple CircleAvatar

class IntertwinedAvatars extends StatelessWidget {
  final ImageProvider? hostImage;
  final ImageProvider? guestImage;
  final double size;
  final Color borderColor;

  const IntertwinedAvatars({
    super.key,
    required this.hostImage,
    required this.guestImage,
    this.size = 80,
    this.borderColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    // Overlap calculation
    final double overlap = size * 0.35; // 35% overlap

    return SizedBox(
      width: (size * 2) - overlap,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Host (Left/Back)
          // We put Host slightly to the left
          Positioned(
            left: 0,
            child: _buildAvatarRing(hostImage, isFront: false),
          ),
          
          // Guest (Right/Front) - "Focus"
          Positioned(
            right: 0,
            child: _buildAvatarRing(guestImage, isFront: true),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarRing(ImageProvider? image, {required bool isFront}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 4.0, // Thick border for separation in overlap
        ),
        boxShadow: isFront ? [
           BoxShadow(
             color: Colors.black.withValues(alpha: 0.1),
             blurRadius: 10,
             offset: const Offset(-4, 0), // Shadow to separate from back avatar
           )
        ] : null,
      ),
      child: ClipOval(
        child: image != null 
            ? Image(image: image, fit: BoxFit.cover)
            : Container(
                color: Colors.grey.shade200,
                child: Icon(Icons.person, color: Colors.grey.shade400, size: size * 0.5),
              ),
      ),
    );
  }
}
