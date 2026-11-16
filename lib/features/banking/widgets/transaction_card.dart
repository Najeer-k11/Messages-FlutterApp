import 'package:material_ui/material_ui.dart';
import 'package:msgs/ui/ui.dart';

class TransactionData {
  final String amount;
  final bool isCredit;
  final String accountOrEntity;

  TransactionData({required this.amount, required this.isCredit, required this.accountOrEntity});

  static final _amount = RegExp(r'(?:\b(?:rs\.?|inr)|₹)\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
  static final _account = RegExp(
    r'(?:a/c|acct|account|card)(?:\s*no\.?)?[\s:]*(?:ending(?:\s+with)?\s*|[x*]+\s*)?(\d{3,6})\b',
    caseSensitive: false,
  );
  static final _credit = RegExp(r'\b(credited|received|deposited|refund(ed)?)\b', caseSensitive: false);
  static final _debit = RegExp(r'\b(debited|spent|paid|withdrawn|sent|purchase)\b', caseSensitive: false);

  static TransactionData? extract(String messageText) {
    final amtMatch = _amount.firstMatch(messageText);
    if (amtMatch == null) return null;
    final amount = amtMatch.group(1)!;

    // "Rs 500 debited from A/c X and credited to beneficiary" is a debit for the reader. Decide
    // by whichever verb comes first rather than by whether "credited" appears anywhere.
    final credit = _credit.firstMatch(messageText)?.start;
    final debit = _debit.firstMatch(messageText)?.start;
    final isCredit = credit != null && (debit == null || credit < debit);

    final acct = _account.firstMatch(messageText);
    final entity = acct != null ? 'A/C …${acct.group(1)}' : 'Account';

    return TransactionData(amount: amount, isCredit: isCredit, accountOrEntity: entity);
  }
}

/// A bank transaction as a list tile: Cookie9 badge (primary = money in, error = money out),
/// title, account, and the amount as the emphasized trailing value.
class TransactionCard extends StatelessWidget {
  final TransactionData data;

  const TransactionCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = data.isCredit ? c.primary : c.error;
    final onAccent = data.isCredit ? c.onPrimary : c.onError;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
        decoration: ShapeDecoration(
          color: context.groupContainer.withValues(alpha: .94),
          shape: Shapes.tile.copyWith(side: BorderSide(color: c.outlineVariant.withValues(alpha: .35), width: 1.25)),
        ),
        child: Row(
          children: [
            ShapeBox(
              size: 48,
              shape: CookieBorder.cookie9,
              color: accent,
              child: Icon(data.isCredit ? Icons.south_west_rounded : Icons.north_east_rounded, color: onAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.isCredit ? 'Received' : 'Spent',
                    style: context.type.titleMediumEmphasized.copyWith(color: c.onSurface),
                  ),
                  Text(
                    data.accountOrEntity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${data.isCredit ? '+' : '−'}₹${data.amount}',
              style: context.type.headlineSmallEmphasized.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
