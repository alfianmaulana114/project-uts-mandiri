import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Empty state widget yang konsisten
/// Menampilkan pesan ketika tidak ada data
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(actionLabel!),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentBlue,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

