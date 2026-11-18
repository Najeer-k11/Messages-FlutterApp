import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgs/features/conversation/conversation_screen.dart';
import 'package:msgs/features/inbox/bloc/inbox_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_state.dart';
import 'package:msgs/features/inbox/widgets/thread_card.dart';
import 'package:msgs/features/settings/blocked_numbers_screen.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/ui/ui.dart';

enum ThreadFolder {
  archived('Archived', Icons.archive_outlined, 'Archived conversations come back when a new message arrives.'),
  spam('Spam', Icons.report_outlined, 'Conversations you report as spam land here and never notify you.');

  const ThreadFolder(this.title, this.icon, this.emptyText);
  final String title;
  final IconData icon;
  final String emptyText;

  List<ThreadModel> of(InboxLoaded state) => this == archived ? state.archived : state.spam;
}

/// Archived or Spam conversations. Same cards as the inbox; swiping right moves one back.
class FolderScreen extends StatelessWidget {
  const FolderScreen({super.key, required this.folder});

  final ThreadFolder folder;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          SizedBox(height: insets.top),
          BackTitleBar(title: folder.title, onBack: () => Navigator.pop(context)),
          Expanded(
            child: BlocBuilder<InboxBloc, InboxState>(
              builder: (context, state) {
                final loaded = state is InboxLoaded ? state : null;
                final threads = loaded == null ? const <ThreadModel>[] : folder.of(loaded);
                return ListView(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, insets.bottom + 24),
                  children: [
                    if (folder == ThreadFolder.spam) ...[
                      SettingsCard(
                        children: [
                          SettingsNavigateRow(
                            icon: Icons.block_rounded,
                            title: 'Blocked numbers',
                            subtitle: 'Senders you won’t hear from',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(builder: (_) => const BlockedNumbersScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (threads.isEmpty)
                      EmptyStateCard(icon: folder.icon, text: folder.emptyText)
                    else
                      for (final thread in threads)
                        ThreadCard(
                          key: ValueKey(thread.address),
                          thread: thread,
                          prefs: loaded!.prefsFor(thread.address),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(builder: (_) => ConversationScreen(thread: thread)),
                          ),
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
