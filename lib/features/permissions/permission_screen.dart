import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:msgs/features/inbox/inbox_screen.dart';
import 'dart:math' as math;

import 'package:msgs/ui/ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _permsDenied = false;

  /// initState and every resume both check permissions; without this guard two checks that
  /// complete together push the inbox twice.
  bool _navigated = false;

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
      final repo = context.read<SmsRepository>();
      _navigateToInbox();

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
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.pushReplacement(context, inboxRoute());
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final insets = MediaQuery.paddingOf(context);
    final denied = _permsDenied;

    return Material(
      color: c.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, insets.top + 24, 24, insets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(child: _Hero(denied: denied)),
            const SizedBox(height: 36),
            _OnboardingSwitcher(
              child: Column(
                key: ValueKey(denied),
                children: [
                  Text(
                    denied ? 'Permission needed' : 'Welcome to Messages',
                    textAlign: TextAlign.center,
                    style: context.type.displaySmallEmphasized.copyWith(color: c.onSurface),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    denied
                        ? 'Messages needs access to SMS and Contacts to work. Please grant both.'
                        : 'Fast, private texting with smart codes and payments, entirely on-device.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge?.copyWith(color: c.onSurfaceVariant),
                  ),
                  if (denied) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: ShapeDecoration(shape: Shapes.sheetGroup, color: context.groupContainer),
                      child: Row(
                        children: [
                          const SettingIcon(Icons.info_outline_rounded),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'On MIUI / HyperOS / Funtouch OS you may need to approve SMS access '
                              'manually in Settings → App permissions.',
                              style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            BigActionButton(
              text: denied ? 'Open app settings' : 'Get started',
              icon: denied ? Icons.settings_rounded : Icons.arrow_forward_rounded,
              loading: _isLoading,
              onTap: denied ? _openSettings : _requestPermissions,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: denied
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: BigActionButton(
                        text: 'Try again',
                        container: c.primaryContainer,
                        content: c.onPrimaryContainer,
                        onTap: _isLoading ? null : _requestPermissions,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onboarding swap: spring slide + 220ms fade.
class _OnboardingSwitcher extends StatelessWidget {
  const _OnboardingSwitcher({required this.child});
  final Widget child;

  static final _curve = SpringCurve(Motion.onboarding);

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: _curve.settleDuration,
    switchInCurve: _curve,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
    transitionBuilder: (child, anim) {
      final incoming = child.key == this.child.key;
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: const Interval(0, .35)),
        child: SlideTransition(
          position: Tween(begin: Offset(incoming ? .25 : -.25, 0), end: Offset.zero).animate(anim),
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// Rotating Cookie12 (primaryContainer, 220dp) with a counter-rotating Sunny (primary, 120dp).
/// 24s linear rotation; the whole thing breathes .96–1.04 over 2.2s.
class _Hero extends StatefulWidget {
  const _Hero({required this.denied});
  final bool denied;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with TickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  late final _breathe = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _spin.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = widget.denied ? c.errorContainer : c.primaryContainer;
    final fg = widget.denied ? c.error : c.primary;
    final onFg = widget.denied ? c.onError : c.onPrimary;
    return AnimatedBuilder(
      animation: Listenable.merge([_spin, _breathe]),
      builder: (context, _) {
        final a = _spin.value * 2 * math.pi;
        final s = .96 + .08 * Curves.easeInOut.transform(_breathe.value);
        return Transform.scale(
          scale: s,
          child: SizedBox.square(
            dimension: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: a,
                  child: AnimatedContainer(
                    duration: Motion.colour,
                    width: 220,
                    height: 220,
                    decoration: ShapeDecoration(shape: CookieBorder.cookie12, color: bg),
                  ),
                ),
                Transform.rotate(
                  angle: -a * 1.5,
                  child: AnimatedContainer(
                    duration: Motion.colour,
                    width: 120,
                    height: 120,
                    decoration: ShapeDecoration(shape: CookieBorder.sunny, color: fg),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    widget.denied ? Icons.lock_rounded : Icons.chat_bubble_rounded,
                    key: ValueKey(widget.denied),
                    size: 48,
                    color: onFg,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
