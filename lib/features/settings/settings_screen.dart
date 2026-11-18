import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/ui/ui.dart';
import 'package:msgs/features/settings/blocked_numbers_screen.dart';

/// Settings slides in from the right (420ms in, 320ms out, FastOutSlowIn).
Route<void> settingsRoute() => PageRouteBuilder<void>(
  transitionDuration: Motion.settingsOpen,
  reverseTransitionDuration: Motion.settingsClose,
  pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
    position: Tween(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn)),
    child: child,
  ),
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  late Future<bool> _isDefault = context.read<SmsRepository>().isDefaultSmsApp();
  final Future<PackageInfo> _info = PackageInfo.fromPlatform();
  late Future<bool> _deliveryReports = context.read<SmsRepository>().deliveryReportsEnabled();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system "default SMS app" dialog or app settings.
    if (state == AppLifecycleState.resumed) {
      setState(() => _isDefault = context.read<SmsRepository>().isDefaultSmsApp());
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ThemeSettingsNotifier>();
    final settings = notifier.value;
    final insets = MediaQuery.paddingOf(context);

    return Material(
      color: context.colors.surface,
      child: Column(
        children: [
          SizedBox(height: insets.top),
          BackTitleBar(title: 'Settings', onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, insets.bottom + 24),
              children: [
                SettingsCard(
                  title: 'Appearance',
                  children: [
                    SettingsNavigateRow(
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme',
                      subtitle: 'Light, dark or follow the system',
                      trailing: settings.darkMode.label,
                      onTap: () async {
                        final mode = await showChoicePicker<DarkMode>(
                          context,
                          title: 'Theme',
                          value: settings.darkMode,
                          options: DarkMode.values,
                          label: (m) => m.label,
                        );
                        if (mode != null) notifier.update(settings.copyWith(darkMode: mode));
                      },
                    ),
                    const SettingsDivider(),
                    SettingsSwitchRow(
                      icon: Icons.contrast_rounded,
                      title: 'Pure black',
                      subtitle: 'True black in dark mode, for OLED screens',
                      value: settings.amoledBlack,
                      onChanged: (v) => notifier.update(settings.copyWith(amoledBlack: v)),
                    ),
                    const SettingsDivider(),
                    PalettePickerRow(
                      dynamicColor: settings.dynamicColor,
                      selected: settings.palette,
                      onDynamic: () => notifier.update(settings.copyWith(dynamicColor: true)),
                      onSelect: (p) => notifier.update(settings.copyWith(dynamicColor: false, palette: p)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SettingsCard(
                  title: 'Messages',
                  children: [
                    FutureBuilder<bool>(
                      future: _isDefault,
                      builder: (context, snap) {
                        final isDefault = snap.data ?? false;
                        return SettingsNavigateRow(
                          icon: Icons.sms_outlined,
                          title: 'Default SMS app',
                          subtitle: isDefault
                              ? 'Messages receives and sends your texts'
                              : 'Needed to receive messages in the background',
                          trailing: snap.hasData ? (isDefault ? 'On' : 'Set') : null,
                          onTap: () => context.read<SmsRepository>().requestDefaultSmsApp(),
                        );
                      },
                    ),
                    const SettingsDivider(),
                    FutureBuilder<bool>(
                      future: _deliveryReports,
                      builder: (context, snap) => SettingsSwitchRow(
                        icon: Icons.done_all_rounded,
                        title: 'Delivery reports',
                        subtitle: 'Show “Delivered” when a text reaches the other phone',
                        value: snap.data ?? true,
                        onChanged: (v) async {
                          await context.read<SmsRepository>().setDeliveryReports(v);
                          if (mounted) setState(() => _deliveryReports = Future.value(v));
                        },
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsNavigateRow(
                      icon: Icons.block_rounded,
                      title: 'Blocked numbers',
                      subtitle: 'Senders you won’t hear from',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const BlockedNumbersScreen()),
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsNavigateRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: 'Sounds, quick reply and code copying',
                      onTap: openAppSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SettingsCard(
                  title: 'About',
                  children: [
                    FutureBuilder<PackageInfo>(
                      future: _info,
                      builder: (context, snap) => SettingsNavigateRow(
                        icon: Icons.info_outline_rounded,
                        title: 'Messages',
                        subtitle: 'Private, on-device texting',
                        trailing: snap.hasData ? 'v${snap.data!.version}' : null,
                        onTap: () => _showChangelog(context),
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsNavigateRow(
                      icon: Icons.history_edu_rounded,
                      title: 'Changelog',
                      subtitle: "What's new in this version",
                      onTap: () => _showChangelog(context),
                    ),
                    const SettingsDivider(),
                    SettingsNavigateRow(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Design credits',
                      subtitle: 'Expressive Clock · Material Clock · Google Sans Flex',
                      onTap: () => _showCredits(context),
                    ),
                    const SettingsDivider(),
                    FutureBuilder<PackageInfo>(
                      future: _info,
                      builder: (context, snap) => SettingsNavigateRow(
                        icon: Icons.gavel_rounded,
                        title: 'Licences',
                        subtitle: 'Open source licences & libraries',
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'Messages',
                          applicationVersion: snap.data?.version,
                          applicationLegalese: '© 2026 Messages Authors. Open Source Software.',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCredits(BuildContext context) {
    showExpressiveSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailsHeader(
              badge: ShapeBox(
                size: 52,
                shape: CookieBorder.sunny,
                color: ctx.colors.primary,
                child: Icon(Icons.auto_awesome_rounded, color: ctx.colors.onPrimary),
              ),
              title: 'Design credits',
            ),
            const SheetGroup(
              children: [
                SheetCreditRow(
                  icon: Icons.schedule_rounded,
                  title: 'Expressive Clock',
                  body: 'Design system adapted from Expressive Clock by Samuel Beckman. MIT licence.',
                ),
                SettingsDivider(),
                SheetCreditRow(
                  icon: Icons.alarm_rounded,
                  title: 'Material Clock',
                  body: 'Expressive Clock is based on Material Clock by Rayane Bouafia. MIT licence.',
                ),
                SettingsDivider(),
                SheetCreditRow(
                  icon: Icons.text_fields_rounded,
                  title: 'Google Sans Flex',
                  body: 'The typeface. SIL Open Font License 1.1.',
                ),
              ],
            ),
            const SizedBox(height: 16),
            BigActionButton(text: 'Done', onTap: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  void _showChangelog(BuildContext context) {
    showExpressiveSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: 'Changelog',
              trailing: SheetHeaderButton(
                text: 'Done',
                primary: true,
                icon: Icons.check_rounded,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            const Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _ChangelogEntry(
                      version: 'v1.2.0',
                      description: 'Material 3 Expressive redesign',
                      items: [
                        'New design: floating dock with search, expressive shapes and motion, Google Sans Flex.',
                        'Photo messages (MMS): send up to three photos, and receive them as the default app.',
                        'Codes disappear when they expire, with the time left shown.',
                        'Money tab for bank transactions, and an Unread tab.',
                        'Wallpaper colours now follow the system on more phones, plus nine palettes and pure black.',
                        'Conversations you have read stay read, even when Android does not save it.',
                        'Mark several conversations as read at once.',
                        'Saved numbers show View contact instead of Add to contacts.',
                        'Bank and OTP texts from senders such as VM-PAYTMB-S are no longer hidden or silenced.',
                        'Fixed the delete confirmation layout.',
                      ],
                    ),
                    SizedBox(height: 12),
                    _ChangelogEntry(
                      version: 'v1.0.0',
                      description: 'Initial release & native features',
                      items: [
                        'Search functionality across inbox threads.',
                        'Theming support with persistent settings.',
                        'Native message deletion from the device.',
                        'Automatic marking of thread as read on chat open.',
                        'Integrated contact picker in compose screen.',
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SheetCreditRow extends StatelessWidget {
  const SheetCreditRow({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingIcon(icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleMedium),
              Text(body, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ChangelogEntry extends StatelessWidget {
  const _ChangelogEntry({required this.version, required this.description, required this.items});

  final String version;
  final String description;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SheetGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: ShapeDecoration(shape: Shapes.pill, color: c.primaryContainer),
                child: Text(version, style: context.type.labelLargeEmphasized.copyWith(color: c.onPrimaryContainer)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(description, style: context.type.titleMediumEmphasized)),
            ],
          ),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: ShapeBox(size: 10, shape: CookieBorder.cookie4, color: c.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item, style: context.text.bodyMedium)),
              ],
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}
