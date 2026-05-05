import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/services/app_lock_service.dart';

class AppLockedPage extends StatefulWidget {
  const AppLockedPage({super.key});

  @override
  State<AppLockedPage> createState() => _AppLockedPageState();
}

class _AppLockedPageState extends State<AppLockedPage> {
  bool _trying = false;

  @override
  void initState() {
    super.initState();
    // Kick off auth shortly after build to ensure navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAuth());
  }

  Future<void> _tryAuth() async {
    if (_trying) return;
    _trying = true;
    final ok = await AppLockService.instance.authenticateOnce(context: context);
    _trying = false;
    if (ok && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Icon(CupertinoIcons.lock_shield, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('App Locked', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Unlock with biometrics or your device passcode to continue.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                CupertinoButton.filled(
                  onPressed: _trying ? null : _tryAuth,
                  child: _trying
                      ? const CupertinoActivityIndicator()
                      : const Text('Unlock'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _trying ? null : () => Navigator.of(context).maybePop(false),
                  child: const Text('Cancel'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
