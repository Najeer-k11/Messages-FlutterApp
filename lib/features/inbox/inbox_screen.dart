import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_state.dart';
import 'package:msgs/features/inbox/bloc/hubs_bloc.dart';
import 'package:msgs/features/inbox/widgets/thread_card.dart';
import 'package:msgs/features/inbox/widgets/smart_fab.dart';
import 'package:msgs/features/inbox/widgets/hubs_section.dart';
import 'package:msgs/features/conversation/conversation_screen.dart';
import 'package:msgs/features/search/search_screen.dart';
import 'package:msgs/features/settings/settings_screen.dart';
import 'package:msgs/features/compose/compose_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExpanded = ValueNotifier<bool>(true);
  late final HubsBloc _hubsBloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // _scrollController.addListener(_onScroll);
    _hubsBloc = HubsBloc(inboxBloc: context.read<InboxBloc>());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _isFabExpanded.dispose();
    _hubsBloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<InboxBloc>().add(SyncInboxEvent());
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider<HubsBloc>.value(
      value: _hubsBloc,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _isFabExpanded,
          builder: (context, isExpanded, child) {
            return SmartFab(
              isExpanded: isExpanded,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ComposeScreen(),
                  ),
                );
              },
            );
          },
        ),
        body: BlocBuilder<InboxBloc, InboxState>(
          builder: (context, state) {
            if (state is InboxLoading || state is InboxInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is InboxError) {
              return Center(child: Text('Error: ${state.message}'));
            }

            if (state is InboxLoaded) {
              final threadsList = state.threads;

              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    title: Text(
                      'Messages',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          showSearch(
                            context: context,
                            delegate: InboxSearchDelegate(threads: threadsList),
                          );
                        },
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'settings') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'settings',
                            child: Row(
                              children: [
                                Icon(Icons.settings_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('Settings'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Refactored horizontal list section (Active OTPs & Recent Transactions)
                  const HubsSection(),

                  SliverPadding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final thread = threadsList[index];
                        return ThreadCard(
                          thread: thread,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ConversationScreen(thread: thread),
                              ),
                            );
                          },
                        );
                      }, childCount: threadsList.length),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
