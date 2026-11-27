import 'package:flex/image_field.dart';

import 'package:flutter/material.dart';

class ExerciseAvatar extends StatelessWidget {
  const ExerciseAvatar({
    super.key,
    required this.name,
    required this.image,
    required this.onTap,
  });

  final String name;
  final String? image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: image != null
        ? Image(
            image: appImageProvider(image!, 64),
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.error),
          )
        : Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
  );
}
