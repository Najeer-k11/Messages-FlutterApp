import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:msgs/features/inbox/inbox_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _permsDenied = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndAdvance();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when user comes back from settings / default SMS dialog.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isLoading) {
      _checkAndAdvance();
    }
  }

  // ── Core Logic ─────────────────────────────────────────────────────────────

  /// Minimum requirement: SMS + Contacts. Notifications and Default SMS are
  /// optional — we prompt but do not block.
  Future<void> _checkAndAdvance() async {
    final smsGranted = await Permission.sms.isGranted;
    final contactsGranted = await Permission.contacts.isGranted;

    if (!mounted) return;

    if (smsGranted && contactsGranted) {
      _navigateToInbox();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _permsDenied = false;
    });

    // Step 1 — Request SMS + Contacts (the only hard requirements)
    final statuses = await [
      Permission.sms,
      Permission.contacts,
      Permission.notification, // soft — don't block if denied
    ].request();

    if (!mounted) return;

    final smsGranted = statuses[Permission.sms]?.isGranted ?? false;
    final contactsGranted = statuses[Permission.contacts]?.isGranted ?? false;

    if (smsGranted && contactsGranted) {
      // Step 2 — Soft-prompt for Default SMS App (fire-and-forget).
      // We navigate immediately; the dialog appears on top.
      // If user accepts, background SMS receiving will work.
      // If user denies, the app still works for reading and sending.
      _navigateToInbox();

      final repo = context.read<SmsRepository>();
      final isDefault = await repo.isDefaultSmsApp();
      if (!isDefault) {
        repo.requestDefaultSmsApp(); // fire and forget
      }
    } else {
      setState(() {
        _isLoading = false;
        _permsDenied = true;
      });
    }
  }

  void _navigateToInbox() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => const InboxScreen(),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                _permsDenied ? Icons.lock_rounded : Icons.message_rounded,
                size: 72,
                color: _permsDenied
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              )
                  .animate(key: ValueKey(_permsDenied))
                  .scale(
                    delay: 100.ms,
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 28),
              Text(
                _permsDenied ? 'Permission required' : 'Welcome to Msgs',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ).animate(key: ValueKey('title_$_permsDenied')).fadeIn(delay: 200.ms),
              const SizedBox(height: 14),
              Text(
                _permsDenied
                    ? 'Msgs needs access to SMS and Contacts to work. Please grant these permissions.'
                    : 'A beautiful, fast, and intelligent messaging experience — entirely on-device.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ).animate(key: ValueKey('sub_$_permsDenied')).fadeIn(delay: 300.ms),
              if (_permsDenied) ...[
                const SizedBox(height: 20),
                // MIUI / OEM note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'On MIUI / HyperOS / Funtouch OS you may need to '
                          'approve SMS access manually in Settings → App permissions.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: _isLoading
                    ? null
                    : (_permsDenied ? _openSettings : _requestPermissions),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_permsDenied
                        ? Icons.settings_rounded
                        : Icons.arrow_forward_rounded),
                label: Text(_permsDenied ? 'Open App Settings' : 'Get Started'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms),
              if (_permsDenied) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isLoading ? null : _requestPermissions,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Try again'),
                ).animate().fadeIn(delay: 600.ms),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
