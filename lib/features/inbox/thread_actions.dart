import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/ui/ui.dart';

/// Conversation actions shared by the inbox, the folders and the conversation screen. Each one
/// confirms with a snackbar that can undo it. The snackbar is shown before the change is written,
/// because the card that triggered it usually leaves the tree as soon as the change lands.

String _count(int n) => n == 1 ? 'Conversation' : '$n conversations';

Future<void> setThreadsArchived(
  BuildContext context,
  List<String> addresses,
  bool archived, {
  bool aboveDock = false,
}) async {
  final repo = context.read<SmsRepository>();
  showExpressiveSnack(
    context,
    '${_count(addresses.length)} ${archived ? 'archived' : 'moved to inbox'}',
    aboveDock: aboveDock,
    onAction: () => repo.setArchived(addresses, !archived),
  );
  await repo.setArchived(addresses, archived);
}

Future<void> setThreadsMuted(BuildContext context, List<String> addresses, bool muted, {bool aboveDock = false}) async {
  final repo = context.read<SmsRepository>();
  showExpressiveSnack(
    context,
    '${_count(addresses.length)} ${muted ? 'muted' : 'unmuted'}',
    aboveDock: aboveDock,
    onAction: () => repo.setMuted(addresses, !muted),
  );
  await repo.setMuted(addresses, muted);
}

Future<void> setThreadsSpam(BuildContext context, List<String> addresses, bool spam, {bool aboveDock = false}) async {
  final repo = context.read<SmsRepository>();
  showExpressiveSnack(
    context,
    spam ? '${_count(addresses.length)} moved to Spam' : '${_count(addresses.length)} moved to inbox',
    aboveDock: aboveDock,
    onAction: () => repo.setSpam(addresses, !spam),
  );
  await repo.setSpam(addresses, spam);
}
