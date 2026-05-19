import 'package:flutter/material.dart';

class TransactionData {
  final String amount;
  final bool isCredit;
  final String accountOrEntity;

  TransactionData({
    required this.amount,
    required this.isCredit,
    required this.accountOrEntity,
  });

  // Very basic extraction for dummy UI purposes
  static TransactionData? extract(String messageText) {
    final lower = messageText.toLowerCase();
    final isCredit = lower.contains('credited') || lower.contains('received');
    
    final amtMatch = RegExp(r'(?:rs\.?|inr)\s?([\d,]+\.?\d*)', caseSensitive: false).firstMatch(messageText);
    if (amtMatch == null) return null;
    
    final amount = amtMatch.group(1)!;

    // Try to extract account ending
    String entity = 'Account';
    final acctMatch = RegExp(r'[a/c|acct].*?(x|ending|no\.?).*?(\d{3,4})', caseSensitive: false).firstMatch(messageText);
    if (acctMatch != null && acctMatch.group(2) != null) {
      entity = 'A/C ...${acctMatch.group(2)}';
    }

    return TransactionData(amount: amount, isCredit: isCredit, accountOrEntity: entity);
  }
}

class TransactionCard extends StatelessWidget {
  final TransactionData data;

  const TransactionCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = data.isCredit ? Colors.green.shade600 : theme.colorScheme.error;
    final icon = data.isCredit ? Icons.arrow_downward : Icons.arrow_upward;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.isCredit ? 'Received' : 'Spent',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '₹${data.amount}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            data.accountOrEntity,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
