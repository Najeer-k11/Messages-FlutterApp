import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/compose/compose_screen.dart' show ExpressiveSearchField;
import 'package:msgs/features/conversation/conversation_screen.dart';
import 'package:msgs/features/inbox/widgets/thread_card.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/ui/ui.dart';

/// Searches sender names, numbers and last messages, then deep-searches every message body.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.threads});

  final List<ThreadModel> threads;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _query.text.trim().toLowerCase();
    final top = MediaQuery.paddingOf(context).top;

    final filtered = term.isEmpty
        ? const <ThreadModel>[]
        : widget.threads.where((t) {
            return t.senderName.toLowerCase().contains(term) ||
                t.address.toLowerCase().contains(term) ||
                t.lastMessage.toLowerCase().contains(term);
          }).toList();

    return Material(
      color: context.colors.surface,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 8),
            child: Row(
              children: [
                RoundTonalButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Back',
                  size: 52,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ExpressiveSearchField(controller: _query, hint: 'Search messages', autofocus: true),
                ),
              ],
            ),
          ),
          Expanded(
            child: term.isEmpty
                ? const _Hint(
                    icon: Icons.manage_search_rounded,
                    title: 'Search everything',
                    body: 'Names, numbers and every message on this device.',
                  )
                : _DeepSearchResults(threads: filtered, searchTerm: term),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpringIn(
              child: ShapeBox(
                size: 96,
                shape: CookieBorder.cookie12,
                color: c.primaryContainer,
                child: Icon(icon, size: 42, color: c.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: context.type.headlineSmallEmphasized.copyWith(color: c.onSurface)),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Combines the thread-level matches with a deep search across all messages in Isar.
class _DeepSearchResults extends StatefulWidget {
  final List<ThreadModel> threads;
  final String searchTerm;

  const _DeepSearchResults({required this.threads, required this.searchTerm});

  @override
  State<_DeepSearchResults> createState() => _DeepSearchResultsState();
}

class _DeepSearchResultsState extends State<_DeepSearchResults> {
  List<ThreadModel>? _deepResults;
  bool _isSearching = false;
  int _generation = 0;

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
    // Results from an older, slower query must not overwrite a newer one.
    final generation = ++_generation;
    setState(() => _isSearching = true);
    try {
      final repo = context.read<SmsRepository>();
      final matchingAddresses = await repo.searchMessageAddresses(widget.searchTerm);
      final existing = widget.threads.map((t) => t.address).toSet();
      final additional = await repo.getThreadsByAddresses(
        matchingAddresses.where((a) => !existing.contains(a)).toList(),
      );
      final combined = [...widget.threads, ...additional]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted && generation == _generation) setState(() => _deepResults = combined);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _deepResults = widget.threads);
    } finally {
      if (mounted && generation == _generation) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _deepResults ?? widget.threads;

    if (_isSearching && results.isEmpty) {
      return const Center(child: ExpressiveLoadingIndicator(contained: true));
    }

    if (results.isEmpty) {
      return _Hint(
        icon: Icons.search_off_rounded,
        title: 'No messages found',
        body: 'Nothing matches “${widget.searchTerm}”.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final thread = results[index];
        return ThreadCard(
          thread: thread,
          dismissible: false,
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ConversationScreen(thread: thread)),
          ),
        );
      },
    );
  }
}
