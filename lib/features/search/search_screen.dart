import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/conversation/conversation_screen.dart';
import 'package:msgs/features/inbox/widgets/thread_card.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';

class InboxSearchDelegate extends SearchDelegate<void> {
  final List<ThreadModel> threads;

  InboxSearchDelegate({required this.threads});

  @override
  String get searchFieldLabel => 'Search conversations...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    final searchTerm = query.trim().toLowerCase();

    if (searchTerm.isEmpty) {
      return _buildEmptyState(
        theme,
        icon: Icons.search_rounded,
        message: 'Search conversations and messages',
        secondary: 'Type a name, number, or message',
      );
    }

    // Search by sender name, address, and last message (thread-level)
    final filtered = threads.where((thread) {
      final name = thread.senderName.toLowerCase();
      final address = thread.address.toLowerCase();
      final body = thread.lastMessage.toLowerCase();
      return name.contains(searchTerm) ||
          address.contains(searchTerm) ||
          body.contains(searchTerm);
    }).toList();

    // Also search all messages in Isar (message-body deep search)
    return _DeepSearchResults(
      threads: filtered,
      searchTerm: searchTerm,
      onClose: (thread) => close(context, null),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme, {
    required IconData icon,
    required String message,
    String? secondary,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 8),
            Text(
              secondary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget that performs a deep search across all messages in Isar
/// and renders the combined thread results.
class _DeepSearchResults extends StatefulWidget {
  final List<ThreadModel> threads;
  final String searchTerm;
  final void Function(ThreadModel thread) onClose;

  const _DeepSearchResults({
    required this.threads,
    required this.searchTerm,
    required this.onClose,
  });

  @override
  State<_DeepSearchResults> createState() => _DeepSearchResultsState();
}

class _DeepSearchResultsState extends State<_DeepSearchResults> {
  List<ThreadModel>? _deepResults;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _performDeepSearch();
  }

  @override
  void didUpdateWidget(_DeepSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchTerm != widget.searchTerm) {
      _performDeepSearch();
    }
  }

  Future<void> _performDeepSearch() async {
    setState(() => _isSearching = true);
    try {
      final repo = context.read<SmsRepository>();

      // Use repository method to search message bodies
      final matchingAddresses = await repo.searchMessageAddresses(widget.searchTerm);

      // Find threads not already in widget.threads that match message search
      final existingAddresses = widget.threads.map((t) => t.address).toSet();
      final newAddresses = matchingAddresses
          .where((a) => !existingAddresses.contains(a))
          .toList();

      final additionalThreads = await repo.getThreadsByAddresses(newAddresses);

      final combined = [...widget.threads, ...additionalThreads];
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) setState(() => _deepResults = combined);
    } catch (_) {
      if (mounted) setState(() => _deepResults = widget.threads);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _deepResults ?? widget.threads;

    if (_isSearching && results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No results for "${widget.searchTerm}"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final thread = results[index];
          return ThreadCard(
            thread: thread,
            onTap: () {
              widget.onClose(thread);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConversationScreen(thread: thread),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
