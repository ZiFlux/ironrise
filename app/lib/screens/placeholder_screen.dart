import 'package:flutter/material.dart';

import '../theme.dart';

/// Заглушка для разделов, которые появятся в следующих спринтах.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.text,
  });

  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
