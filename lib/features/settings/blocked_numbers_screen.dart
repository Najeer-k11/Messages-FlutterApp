import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/ui/ui.dart';

/// The system block list, which the Phone app shares. Unblocking brings the conversation back.
class BlockedNumbersScreen extends StatefulWidget {
  const BlockedNumbersScreen({super.key});

  @override
  State<BlockedNumbersScreen> createState() => _BlockedNumbersScreenState();
}

class _BlockedNumbersScreenState extends State<BlockedNumbersScreen> {
  late Future<({bool allowed, List<String> numbers})> _data = _load();

  Future<({bool allowed, List<String> numbers})> _load() async {
    final repo = context.read<SmsRepository>();
    if (!await repo.canBlockNumbers()) return (allowed: false, numbers: const <String>[]);
    return (allowed: true, numbers: await repo.getBlockedNumbers());
  }

  Future<void> _unblock(String number) async {
    try {
      await context.read<SmsRepository>().unblockNumber(number);
      if (mounted) showExpressiveSnack(context, '$number unblocked');
    } catch (_) {
      if (mounted) showExpressiveSnack(context, 'Couldn’t unblock $number');
    }
    if (mounted) setState(() => _data = _load());
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Material(
      color: context.colors.surface,
      child: Column(
        children: [
          SizedBox(height: insets.top),
          BackTitleBar(title: 'Blocked numbers', onBack: () => Navigator.pop(context)),
          Expanded(
            child: FutureBuilder(
              future: _data,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: ExpressiveLoadingIndicator(contained: true));
                }
                final data = snap.data!;
                return ListView(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, insets.bottom + 24),
                  children: [
                    if (!data.allowed)
                      EmptyStateCard(
                        icon: Icons.block_rounded,
                        text: 'Set Messages as the default SMS app to see and manage blocked numbers.',
                        actionLabel: 'Set default',
                        onAction: () async {
                          await context.read<SmsRepository>().requestDefaultSmsApp();
                          if (mounted) setState(() => _data = _load());
                        },
                      )
                    else if (data.numbers.isEmpty)
                      const EmptyStateCard(
                        icon: Icons.block_rounded,
                        text: 'No blocked numbers. Block a sender from the menu in their conversation.',
                      )
                    else
                      SettingsCard(
                        children: [
                          for (final (i, number) in data.numbers.indexed) ...[
                            if (i > 0) const SettingsDivider(),
                            SettingsNavigateRow(
                              icon: Icons.block_rounded,
                              title: number,
                              trailing: 'Unblock',
                              onTap: () => _unblock(number),
                            ),
                          ],
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
