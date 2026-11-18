import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/banking/widgets/transaction_card.dart';
import 'package:msgs/features/compose/compose_screen.dart';
import 'package:msgs/features/conversation/conversation_screen.dart';
import 'package:msgs/features/inbox/bloc/hubs_bloc.dart';
import 'package:msgs/features/inbox/folder_screen.dart';
import 'package:msgs/features/inbox/thread_actions.dart';
import 'package:msgs/features/inbox/bloc/inbox_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_event.dart';
import 'package:msgs/features/inbox/bloc/inbox_state.dart';
import 'package:msgs/features/inbox/widgets/hubs_section.dart';
import 'package:msgs/features/inbox/widgets/thread_card.dart';
import 'package:msgs/features/search/search_screen.dart';
import 'package:msgs/features/settings/settings_screen.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/ui/ui.dart';

/// Fades in; slides back by 1/8 while another page covers it.
Route<void> inboxRoute() => PageRouteBuilder<void>(
  pageBuilder: (context, animation, secondaryAnimation) => const InboxScreen(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween(
        begin: Offset.zero,
        end: const Offset(-1 / 8, 0),
      ).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.fastOutSlowIn)),
      child: child,
    ),
  ),
);

enum _Tab { chats, unread, money }

/// The app shell: full-bleed tab content, a fixed top row (search pill, settings gear) and the
/// floating [ExpressiveDock] with a detached "new message" button.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  late final HubsBloc _hubsBloc;
  StreamSubscription? _intentSubscription;

  _Tab _tab = _Tab.chats;
  _Tab _previousTab = _Tab.chats;

  // Multi-select state
  final Set<String> _selectedAddresses = {};
  bool get _isSelecting => _selectedAddresses.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hubsBloc = HubsBloc(inboxBloc: context.read<InboxBloc>());

    final smsRepo = context.read<SmsRepository>();
    _intentSubscription = smsRepo.intentStream.listen(_handleIntentData);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final data = await smsRepo.getPendingIntentData();
      if (data != null) _handleIntentData(data);
    });
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _hubsBloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<InboxBloc>().add(SyncInboxEvent());
    }
  }

  // ── Intents ────────────────────────────────────────────────────────────────

  void _handleIntentData(Map<String, String> data) {
    if (!mounted) return;
    final address = data['address'] ?? '';
    final body = data['body'] ?? '';
    if (address.isEmpty && body.isEmpty) return;

    // An address with an existing thread → straight to the conversation.
    if (address.isNotEmpty) {
      final normalizedAddress = SmsRepository.normalizeAddress(address);
      final state = context.read<InboxBloc>().state;
      if (state is InboxLoaded) {
        final existingThread = [...state.threads, ...state.archived, ...state.spam].cast<ThreadModel?>().firstWhere(
          (t) => t != null && (SmsRepository.normalizeAddress(t.address) == normalizedAddress || t.address == address),
          orElse: () => null,
        );
        if (existingThread != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ConversationScreen(thread: existingThread, initialBody: body.isNotEmpty ? body : null),
            ),
          );
          return;
        }
      }
      // New or unknown number: create the thread and open it.
      openConversation(context, address: address, name: address, initialBody: body.isNotEmpty ? body : null);
      return;
    }

    // Body only (shared text): pick a recipient first.
    showComposeSheet(context, initialBody: body);
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void _toggleSelection(ThreadModel thread) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedAddresses.remove(thread.address)) {
        _selectedAddresses.add(thread.address);
      }
    });
  }

  void _clearSelection() => setState(_selectedAddresses.clear);

  void _toggleSelectAll(List<ThreadModel> visible) {
    setState(() {
      final all = visible.map((t) => t.address).toSet();
      if (_selectedAddresses.containsAll(all)) {
        _selectedAddresses.removeAll(all);
      } else {
        _selectedAddresses.addAll(all);
      }
    });
  }

  Future<void> _markSelectedRead(List<ThreadModel> allThreads) async {
    final selected = allThreads.where((t) => _selectedAddresses.contains(t.address)).toList();
    final unread = selected.where((t) => t.unreadCount > 0).length;
    _clearSelection();
    await context.read<SmsRepository>().markThreadsAsRead([
      for (final t in selected) (address: t.address, nativeThreadId: t.nativeThreadId),
    ]);
    if (!mounted) return;
    showExpressiveSnack(
      context,
      unread == 0 ? 'Already read' : 'Marked $unread conversation${unread == 1 ? '' : 's'} as read',
      aboveDock: true,
    );
  }

  Future<void> _archiveSelected() async {
    final addresses = _selectedAddresses.toList();
    _clearSelection();
    await setThreadsArchived(context, addresses, true, aboveDock: true);
  }

  void _showFolders(InboxState state) {
    final loaded = state is InboxLoaded ? state : null;
    showExpressiveSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SheetGroup(
          children: [
            for (final (i, folder) in ThreadFolder.values.indexed) ...[
              if (i > 0) const SettingsDivider(),
              SheetActionRow(
                icon: folder.icon,
                title: folder.title,
                subtitle: switch (loaded == null ? 0 : folder.of(loaded).length) {
                  0 => 'Empty',
                  1 => '1 conversation',
                  final n => '$n conversations',
                },
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => FolderScreen(folder: folder)));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBatchDelete(List<ThreadModel> allThreads) async {
    final count = _selectedAddresses.length;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete $count conversation${count > 1 ? 's' : ''}?',
      message: 'This permanently deletes ${count > 1 ? 'them' : 'it'} and all their messages.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    final threadsToDelete = allThreads
        .where((t) => _selectedAddresses.contains(t.address))
        .map((t) => (address: t.address, nativeThreadId: t.nativeThreadId))
        .toList();
    context.read<InboxBloc>().add(BatchDeleteThreadsEvent(threads: threadsToDelete));
    _clearSelection();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Dock index of the Search item, which opens the search screen rather than switching tabs.
  static final _searchIndex = _Tab.values.length;

  void _onDockSelect(int i, List<ThreadModel> threads) {
    if (i == _searchIndex) {
      _openSearch(threads);
    } else {
      _selectTab(i);
    }
  }

  void _selectTab(int i) {
    final next = _Tab.values[i];
    if (next == _tab) return;
    setState(() {
      _previousTab = _tab;
      _tab = next;
      _selectedAddresses.clear();
    });
  }

  void _openSearch(List<ThreadModel> threads) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(threads: threads)));

  void _openThread(ThreadModel thread) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(thread: thread)));

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);

    return BlocProvider<HubsBloc>.value(
      value: _hubsBloc,
      child: BlocBuilder<InboxBloc, InboxState>(
        builder: (context, state) {
          final threads = state is InboxLoaded ? state.threads : const <ThreadModel>[];
          final unreadThreads = threads.where((t) => t.unreadCount > 0).toList();

          return PopScope(
            canPop: !_isSelecting && _tab == _Tab.chats,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_isSelecting) {
                _clearSelection();
              } else {
                _selectTab(_Tab.chats.index);
              }
            },
            child: Scaffold(
              backgroundColor: context.colors.surface,
              resizeToAvoidBottomInset: false,
              body: Stack(
                children: [
                  // 1. Content, full-bleed.
                  Positioned.fill(child: _content(state, threads, unreadThreads)),
                  const Positioned(top: 0, left: 0, right: 0, child: StatusBarFade()),
                  // 2. Top row: settings gear (and a Cancel pill while selecting).
                  Positioned(
                    top: insets.top + 8,
                    left: 16,
                    right: 16,
                    child: _TopRow(
                      selecting: _isSelecting,
                      onCancelSelection: _clearSelection,
                      onFolders: () => _showFolders(state),
                      onSettings: () => Navigator.push(context, settingsRoute()),
                    ),
                  ),
                  // 3. The dock, floating.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: insets.bottom + 20,
                    child: Center(
                      child: ExpressiveDock(
                        selected: _tab.index,
                        onSelect: (i) => _onDockSelect(i, state is InboxLoaded ? state.notSpam : threads),
                        showAdd: !_isSelecting && _tab != _Tab.money,
                        addLabel: 'New message',
                        onAdd: () => showComposeSheet(context),
                        destinations: [
                          const DockDestination(
                            'chats',
                            'Chats',
                            Icons.chat_bubble_outline_rounded,
                            Icons.chat_bubble_rounded,
                            TapMotion.flip,
                          ),
                          DockDestination(
                            'unread',
                            'Unread',
                            Icons.mark_chat_unread_outlined,
                            Icons.mark_chat_unread_rounded,
                            TapMotion.wiggle,
                            badge: unreadThreads.length,
                          ),
                          const DockDestination(
                            'money',
                            'Money',
                            Icons.account_balance_wallet_outlined,
                            Icons.account_balance_wallet_rounded,
                            TapMotion.halfTurn,
                          ),
                          const DockDestination(
                            'search',
                            'Search',
                            Icons.search_rounded,
                            Icons.search_rounded,
                            TapMotion.fullTurn,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static final _tabCurve = SpringCurve(Motion.spring(0.85, 380));

  Widget _content(InboxState state, List<ThreadModel> threads, List<ThreadModel> unread) {
    if (state is InboxLoading || state is InboxInitial) {
      return const Center(child: ExpressiveLoadingIndicator(contained: true, size: 64));
    }
    if (state is InboxError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyStateCard(
            icon: Icons.error_outline_rounded,
            text: 'Couldn’t load your messages.\n${state.message}',
            actionLabel: 'Retry',
            onAction: () => context.read<InboxBloc>().add(SyncInboxEvent()),
          ),
        ),
      );
    }

    final dir = _tab.index >= _previousTab.index ? 1.0 : -1.0;
    final current = ValueKey(_tab);
    return AnimatedSwitcher(
      duration: _tabCurve.settleDuration,
      switchInCurve: _tabCurve,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) {
        final incoming = child.key == current;
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: const Interval(0, .45)),
          child: SlideTransition(
            position: Tween(begin: Offset((incoming ? dir : -dir) * .18, 0), end: Offset.zero).animate(anim),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: current,
        child: switch (_tab) {
          _Tab.chats => _threadList(
            key: 'chats',
            title: 'Messages',
            subtitle: unread.isEmpty ? 'All caught up' : '${unread.length} unread',
            threads: threads,
            allThreads: threads,
            showHubs: true,
            empty: EmptyStateCard(
              icon: Icons.forum_outlined,
              text: 'No conversations yet.',
              actionLabel: 'Start one',
              onAction: () => showComposeSheet(context),
            ),
          ),
          _Tab.unread => _threadList(
            key: 'unread',
            title: 'Unread',
            subtitle: unread.isEmpty
                ? 'Nothing waiting'
                : '${unread.length} conversation${unread.length == 1 ? '' : 's'}',
            threads: unread,
            allThreads: threads,
            empty: const EmptyStateCard(icon: Icons.done_all_rounded, text: 'You’re all caught up.'),
          ),
          _Tab.money => _moneyList(),
        },
      ),
    );
  }

  EdgeInsets _listPadding() {
    final insets = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(16, insets.top + 64, 16, kDockReserve + insets.bottom + 24);
  }

  Widget _threadList({
    required String key,
    required String title,
    required String subtitle,
    required List<ThreadModel> threads,
    required List<ThreadModel> allThreads,
    required Widget empty,
    bool showHubs = false,
  }) {
    final c = context.colors;
    final selectedVisible = threads.where((t) => _selectedAddresses.contains(t.address)).length;
    final header = _isSelecting
        ? ScreenHeader(
            title: '${_selectedAddresses.length} selected',
            subtitle: 'Tap to select more',
            trailing: [
              RoundTonalButton(
                icon: selectedVisible == threads.length ? Icons.deselect_rounded : Icons.select_all_rounded,
                label: selectedVisible == threads.length ? 'Deselect all' : 'Select all',
                onTap: () => _toggleSelectAll(threads),
              ),
              RoundTonalButton(
                icon: Icons.mark_chat_read_outlined,
                label: 'Mark selected as read',
                onTap: () => _markSelectedRead(allThreads),
              ),
              RoundTonalButton(icon: Icons.archive_outlined, label: 'Archive selected', onTap: _archiveSelected),
              RoundTonalButton(
                icon: Icons.delete_outline_rounded,
                label: 'Delete selected',
                container: c.errorContainer,
                content: c.onErrorContainer,
                onTap: () => _confirmBatchDelete(allThreads),
              ),
            ],
          )
        : ScreenHeader(title: title, subtitle: subtitle);

    return CustomScrollView(
      key: PageStorageKey(key),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: _listPadding(),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: header),
              if (showHubs && !_isSelecting)
                const HubsSection()
              else
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (threads.isEmpty)
                SliverToBoxAdapter(child: empty)
              else
                SliverList.builder(
                  itemCount: threads.length,
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    final inbox = context.read<InboxBloc>().state;
                    return ThreadCard(
                      key: ValueKey(thread.address),
                      thread: thread,
                      prefs: inbox is InboxLoaded ? inbox.prefsFor(thread.address) : null,
                      snackAboveDock: true,
                      isSelected: _selectedAddresses.contains(thread.address),
                      isSelecting: _isSelecting,
                      onTap: () => _isSelecting ? _toggleSelection(thread) : _openThread(thread),
                      onLongPress: () => _toggleSelection(thread),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _moneyList() {
    return BlocBuilder<HubsBloc, HubsState>(
      builder: (context, state) {
        final txns = state is HubsLoaded ? state.recentTransactions : const [];
        return CustomScrollView(
          key: const PageStorageKey('money'),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: _listPadding(),
              sliver: SliverMainAxisGroup(
                slivers: [
                  const SliverToBoxAdapter(
                    child: ScreenHeader(title: 'Money', subtitle: 'From your bank texts'),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  if (state is! HubsLoaded)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: ExpressiveLoadingIndicator(contained: true)),
                      ),
                    )
                  else if (txns.isEmpty)
                    const SliverToBoxAdapter(
                      child: EmptyStateCard(
                        icon: Icons.account_balance_wallet_outlined,
                        text: 'Payments and bank alerts will show up here.',
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: txns.length,
                      itemBuilder: (context, i) => TransactionCard(data: txns[i]),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.selecting,
    required this.onCancelSelection,
    required this.onFolders,
    required this.onSettings,
  });

  final bool selecting;
  final VoidCallback onCancelSelection;
  final VoidCallback onFolders;
  final VoidCallback onSettings;

  static final _pillCurve = SpringCurve(Motion.pillAppear);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: _pillCurve),
              child: child,
            ),
          ),
          child: selecting
              ? _Pill(
                  key: const ValueKey('cancel'),
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  onTap: onCancelSelection,
                )
              : const SizedBox(key: ValueKey('none'), height: 48),
        ),
        const Spacer(),
        AnimatedOpacity(
          opacity: selecting ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: selecting,
            child: Row(
              children: [
                RoundTonalButton(
                  icon: Icons.inventory_2_outlined,
                  label: 'Archived and spam',
                  onTap: onFolders,
                  container: c.surfaceContainerHigh,
                  content: c.onSurface,
                ),
                const SizedBox(width: 8),
                RoundTonalButton(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: onSettings,
                  container: c.surfaceContainerHigh,
                  content: c.onSurface,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Left-side tonal pill (search / cancel selection).
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LuminousElastic.small(
      shape: Shapes.pill,
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 14, right: 18),
        decoration: ShapeDecoration(shape: Shapes.pill, color: c.primaryContainer),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: c.onPrimaryContainer),
            const SizedBox(width: 8),
            Text(label, style: context.type.labelLargeEmphasized.copyWith(color: c.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}
