import 'package:flutter/material.dart';

import '../../core/utils/haptics.dart';

/// Reusable "are you sure?" dialog for destructive actions.
/// Returns true if confirmed, false or null if cancelled.
class ConfirmDialog {
  ConfirmDialog._();

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    bool destructive = true,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: icon != null
            ? Icon(icon, color: destructive ? Colors.redAccent : null)
            : null,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.redAccent)
                : null,
            onPressed: () {
              Haptics.heavy();
              Navigator.pop(context, true);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
