import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_event.dart';
import 'package:msgs/features/inbox/bloc/inbox_state.dart';
import 'package:msgs/features/inbox/bloc/hubs_bloc.dart';
import 'package:msgs/features/inbox/widgets/thread_card.dart';
import 'package:msgs/features/inbox/widgets/smart_fab.dart';
import 'package:msgs/features/inbox/widgets/hubs_section.dart';
import 'package:msgs/features/conversation/conversation_screen.dart';
import 'package:msgs/features/search/search_screen.dart';
import 'package:msgs/features/settings/settings_screen.dart';
import 'package:msgs/features/compose/compose_screen.dart';
import 'package:msgs/services/sms/models/thread_model.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExpanded = ValueNotifier<bool>(true);
  late final HubsBloc _hubsBloc;

  // Multi-select state
  final Set<String> _selectedAddresses = {};
  bool get _isSelecting => _selectedAddresses.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hubsBloc = HubsBloc(inboxBloc: context.read<InboxBloc>());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  void _toggleSelection(ThreadModel thread) {
    setState(() {
      if (_selectedAddresses.contains(thread.address)) {
        _selectedAddresses.remove(thread.address);
      } else {
        _selectedAddresses.add(thread.address);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedAddresses.clear();
    });
  }

  Future<void> _confirmBatchDelete(List<ThreadModel> allThreads) async {
    final count = _selectedAddresses.length;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete conversations?'),
            content: Text(
              'This will permanently delete $count conversation${count > 1 ? 's' : ''} and all their messages.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final threadsToDelete = allThreads
        .where((t) => _selectedAddresses.contains(t.address))
        .map((t) => (address: t.address, nativeThreadId: t.nativeThreadId))
        .toList();

    if (mounted) {
      context.read<InboxBloc>().add(
        BatchDeleteThreadsEvent(threads: threadsToDelete),
      );
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider<HubsBloc>.value(
      value: _hubsBloc,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        floatingActionButton: _isSelecting
            ? null
            : ValueListenableBuilder<bool>(
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
                  _isSelecting
                      ? _buildSelectionAppBar(theme, threadsList)
                      : _buildDefaultAppBar(theme, threadsList),

                  // Refactored horizontal list section (Active OTPs & Recent Transactions)
                  const HubsSection(),

                  SliverPadding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final thread = threadsList[index];
                        final isSelected = _selectedAddresses.contains(
                          thread.address,
                        );

                        return ThreadCard(
                          thread: thread,
                          isSelected: isSelected,
                          isSelecting: _isSelecting,
                          onTap: () {
                            if (_isSelecting) {
                              _toggleSelection(thread);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ConversationScreen(thread: thread),
                                ),
                              );
                            }
                          },
                          onLongPress: () {
                            _toggleSelection(thread);
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

  SliverAppBar _buildDefaultAppBar(
    ThemeData theme,
    List<ThreadModel> threadsList,
  ) {
    return SliverAppBar(
      pinned: true,
      title: Text('Messages', style: TextStyle(fontWeight: FontWeight.bold)),
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
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
    );
  }

  SliverAppBar _buildSelectionAppBar(
    ThemeData theme,
    List<ThreadModel> threadsList,
  ) {
    return SliverAppBar(
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      title: Text(
        '${_selectedAddresses.length} selected',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: 'Select all',
          onPressed: () {
            setState(() {
              if (_selectedAddresses.length == threadsList.length) {
                _selectedAddresses.clear();
              } else {
                _selectedAddresses.clear();
                for (final t in threadsList) {
                  _selectedAddresses.add(t.address);
                }
              }
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete selected',
          onPressed: () => _confirmBatchDelete(threadsList),
        ),
      ],
    );
  }
}
