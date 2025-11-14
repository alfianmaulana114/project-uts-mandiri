import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Header widget yang konsisten untuk semua screen
/// Menggunakan design yang modern dan rapi
class CommonHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const CommonHeader({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const Spacer(),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

