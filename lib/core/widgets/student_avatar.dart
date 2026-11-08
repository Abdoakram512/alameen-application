import 'package:flutter/material.dart';
import 'app_cached_image.dart';

class StudentAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final double? fontSize;

  const StudentAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.fontSize,
  });

  String _getInitials(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return 'ط';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].characters.take(2).toString();
    }
    return '${parts[0].characters.take(1)}${parts[1].characters.take(1)}';
  }

  bool _isGenericPlaceholder(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    return url.contains('unsplash.com');
  }

  @override
  Widget build(BuildContext context) {
    final hasRealImage = !_isGenericPlaceholder(photoUrl);

    if (hasRealImage) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: AppCachedImage(
            imageUrl: photoUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final initials = _getInitials(name);
    final size = fontSize ?? (radius * 0.75);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF012383), // Navy Blue
            Color(0xFF1E3A8A), // Royal Blue
          ],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF012383).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

