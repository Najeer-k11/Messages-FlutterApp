import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/features/conversation/conversation_screen.dart';
import 'package:isar/isar.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _allContacts = [];
  List<Map<String, String>> _filteredContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final repo = context.read<SmsRepository>();
    final contacts = await repo.getContacts();
    if (mounted) {
      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        _filteredContacts = _allContacts.where((c) {
          final name = c['name']?.toLowerCase() ?? '';
          final number = c['number']?.toLowerCase() ?? '';
          return name.contains(query) || number.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _startConversation(String address, String name) async {
    final normalizedAddress = SmsRepository.normalizeAddress(address);
    if (normalizedAddress.isEmpty) return;

    final repo = context.read<SmsRepository>();
    final isar = repo.isar;

    // Check if thread already exists in Isar
    var thread = await isar.threadModels
        .filter()
        .addressEqualTo(normalizedAddress)
        .findFirst();

    if (thread == null) {
      var resolvedName = name;
      // If name matches the original typed address, try to look up a real contact name
      if (name == address) {
        try {
          final contacts = await repo.getContacts();
          for (final contact in contacts) {
            final cName = contact['name'] ?? '';
            final cNum = contact['number'] ?? '';
            if (cName.isNotEmpty && cNum.isNotEmpty && SmsRepository.normalizeAddress(cNum) == normalizedAddress) {
              resolvedName = cName;
              break;
            }
          }
        } catch (_) {}
      }

      thread = ThreadModel()
        ..address = normalizedAddress
        ..senderName = resolvedName.isNotEmpty ? resolvedName : normalizedAddress
        ..lastMessage = ''
        ..timestamp = DateTime.now()
        ..unreadCount = 0;

      await isar.writeTxn(() async {
        await isar.threadModels.put(thread!);
      });
    }

    if (mounted) {
      // Replace Compose screen with Conversation screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationScreen(thread: thread!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSearchQueryValidNumber = RegExp(r'^\+?[0-9\-\s\(\)]{3,}$')
        .hasMatch(_searchController.text.trim());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New message',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    hintText: 'Type a name or phone number...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28.0),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28.0),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28.0),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
              ),
              if (_searchController.text.trim().isNotEmpty && isSearchQueryValidNumber)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.message_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      'Send to "${_searchController.text.trim()}"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Start messaging this number'),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () {
                      _startConversation(
                        _searchController.text.trim(),
                        _searchController.text.trim(),
                      );
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    tileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _filteredContacts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No contacts found',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                            itemCount: _filteredContacts.length,
                            itemBuilder: (context, index) {
                              final contact = _filteredContacts[index];
                              final name = contact['name'] ?? '';
                              final number = contact['number'] ?? '';
                              final initial = name.isNotEmpty
                                  ? name.substring(0, 1).toUpperCase()
                                  : '?';

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 4.0,
                                ),
                                child: InkWell(
                                  onTap: () => _startConversation(number, name),
                                  borderRadius: BorderRadius.circular(16.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: theme.colorScheme.primaryContainer,
                                          child: Text(
                                            initial,
                                            style: TextStyle(
                                              color: theme.colorScheme.onPrimaryContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                number,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(delay: (20 * index).ms).slideY(
                                    begin: 0.1,
                                    end: 0,
                                    curve: Curves.easeOutCubic,
                                  );
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
