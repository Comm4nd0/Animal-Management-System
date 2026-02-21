import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/animal_provider.dart';
import '../utils/app_theme.dart';

/// Checks whether write operations are allowed.
///
/// When the user has a read-only role, shows a friendly dialog explaining
/// the restriction and returns `false`. Otherwise returns `true`.
///
/// Usage:
/// ```dart
/// onPressed: () async {
///   if (!await guardWriteAction(context)) return;
///   // ... perform the write operation
/// }
/// ```
Future<bool> guardWriteAction(BuildContext context) async {
  final provider = context.read<AnimalProvider>();
  if (provider.canWrite) return true;

  await showDialog<void>(
    context: context,
    builder: (_) => const _DemoUpgradeDialog(),
  );
  return false;
}

class _DemoUpgradeDialog extends StatelessWidget {
  const _DemoUpgradeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.lock_outline, size: 40, color: AppTheme.accentColor),
      title: const Text('Read-Only Access'),
      content: const Text(
        'Your account has read-only access. Contact your account owner to get write permissions, or create your own account.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep Browsing'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/register');
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
          ),
          child: const Text('Sign Up Free'),
        ),
      ],
    );
  }
}
