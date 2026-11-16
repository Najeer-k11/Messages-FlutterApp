import 'package:material_ui/material_ui.dart';
import 'package:isar_community/isar.dart';
import 'package:provider/provider.dart';
import 'package:msgs/features/conversation/conversation_screen.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/ui/ui.dart';

final _phonePattern = RegExp(r'^\+?[0-9\-\s\(\)]{3,}$');

/// Finds (or creates) the thread for [address] and opens it.
Future<void> openConversation(
  BuildContext context, {
  required String address,
  required String name,
  String? initialBody,
}) async {
  final normalizedAddress = SmsRepository.normalizeAddress(address);
  if (normalizedAddress.isEmpty) return;

  final repo = context.read<SmsRepository>();
  final navigator = Navigator.of(context);
  final isar = repo.isar;

  var thread = await isar.threadModels.filter().addressEqualTo(normalizedAddress).findFirst();

  if (thread == null) {
    var resolvedName = name;
    // A typed number: try to resolve a real contact name for it.
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
      ..timestamp = DateTime.now().toUtc()
      ..unreadCount = 0;

    await isar.writeTxn(() async {
      await isar.threadModels.put(thread!);
    });
  }

  navigator.push(
    MaterialPageRoute(
      builder: (context) => ConversationScreen(thread: thread!, initialBody: initialBody),
    ),
  );
}

/// The "new message" create flow: a full-height sheet with Cancel · title · Start, a search field,
/// and the contact list.
Future<void> showComposeSheet(BuildContext context, {String? initialBody}) async {
  final picked = await showExpressiveSheet<({String address, String name})>(
    context,
    fullHeight: true,
    builder: (ctx) => const _ComposeSheet(),
  );
  if (picked != null && context.mounted) {
    await openConversation(context, address: picked.address, name: picked.name, initialBody: initialBody);
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final TextEditingController _query = TextEditingController();
  List<Map<String, String>> _all = [];
  List<Map<String, String>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _query.addListener(_onQuery);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final contacts = await context.read<SmsRepository>().getContacts();
    if (!mounted) return;
    setState(() {
      _all = contacts;
      _filtered = contacts;
      _loading = false;
    });
  }

  void _onQuery() {
    final q = _query.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((c) {
              final name = c['name']?.toLowerCase() ?? '';
              final number = c['number']?.toLowerCase() ?? '';
              return name.contains(q) || number.contains(q);
            }).toList();
    });
  }

  void _pick(String address, String name) => Navigator.pop(context, (address: address, name: name));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final typed = _query.text.trim();
    final validNumber = typed.isNotEmpty && _phonePattern.hasMatch(typed);

    return Column(
      children: [
        SheetHeader(
          title: 'New message',
          leading: SheetHeaderButton(text: 'Cancel', onTap: () => Navigator.pop(context)),
          trailing: SheetHeaderButton(
            text: 'Start',
            primary: true,
            icon: Icons.arrow_forward_rounded,
            enabled: validNumber,
            onTap: () => _pick(typed, typed),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: ExpressiveSearchField(controller: _query, hint: 'Name or phone number', autofocus: true),
        ),
        if (validNumber)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SpringIn(
              rotate: false,
              child: SheetGroup(
                color: c.primaryContainer,
                children: [
                  SheetActionRow(
                    icon: Icons.sms_outlined,
                    title: 'Send to $typed',
                    subtitle: 'Start messaging this number',
                    onTap: () => _pick(typed, typed),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: ExpressiveLoadingIndicator(contained: true))
              : _filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: EmptyStateCard(
                      icon: Icons.person_search_rounded,
                      text: typed.isEmpty ? 'No contacts on this device' : 'No contacts match “$typed”',
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipPath(
                    clipper: ShapeBorderClipper(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
                    ),
                    child: ColoredBox(
                      color: c.surfaceContainerHigh,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => const SettingsDivider(),
                        itemBuilder: (context, i) {
                          final contact = _filtered[i];
                          final name = contact['name'] ?? '';
                          final number = contact['number'] ?? '';
                          return _ContactRow(name: name, number: number, onTap: () => _pick(number, name));
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.name, required this.number, required this.onTap});

  final String name;
  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initial = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : '?';
    return LuminousElastic(
      shape: Shapes.row,
      maxStretch: .03,
      maxTranslate: 1.2,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ShapeBox(
              size: 46,
              shape: Shapes.circle,
              color: c.primaryContainer,
              child: Text(initial, style: context.type.titleMediumEmphasized.copyWith(color: c.onPrimaryContainer)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                  Text(number, style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 20dp-rounded search field on surfaceContainerHighest. Shared with the search screen.
class ExpressiveSearchField extends StatelessWidget {
  const ExpressiveSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 56,
      decoration: ShapeDecoration(shape: Shapes.row, color: c.surfaceContainerHighest),
      padding: const EdgeInsets.only(left: 16, right: 6),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: c.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: context.text.bodyLarge?.copyWith(color: c.onSurface),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: context.text.bodyLarge?.copyWith(color: c.onSurfaceVariant.withValues(alpha: .6)),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox(width: 10)
                : RoundTonalButton(
                    icon: Icons.close_rounded,
                    label: 'Clear',
                    size: 40,
                    container: c.surfaceContainerHigh,
                    content: c.onSurfaceVariant,
                    onTap: controller.clear,
                  ),
          ),
        ],
      ),
    );
  }
}
