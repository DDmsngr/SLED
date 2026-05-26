import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/entities/photo_marker.dart';

/// Круглая миниатюра фото на карте.
class PhotoMarkerWidget extends StatelessWidget {
  const PhotoMarkerWidget({super.key, required this.photo});
  final PhotoMarker photo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipOval(
        child: Image.file(
          File(photo.filePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Colors.grey,
            child: Icon(Icons.broken_image, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
