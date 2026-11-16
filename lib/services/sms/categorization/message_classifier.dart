enum MessageCategory { otp, banking, promotions, personal, spam, unknown }

class MessageClassifier {
  // Whole-word matches only: a bare substring test for "pin" also fires on "shopping" and
  // "opinion", which classified ordinary messages as one-time codes.
  static final _otp = RegExp(
    r'\b(otp|one[\s-]?time\s+(pass(word|code)?|code)|verification\s+code|passcode|pin|code\s+is)\b',
    caseSensitive: false,
  );
  static final _otpDigits = RegExp(r'\b\d{4,8}\b');
  static final _code = RegExp(r'\bcode\b', caseSensitive: false);
  static final _banking = RegExp(
    r'\b(debited|credited|a/c|acct|account|upi|transaction|txn)\b|(\brs\.?|\binr|₹)\s?\d',
    caseSensitive: false,
  );
  static final _promo = RegExp(r'\b(offer|discount|sale|cashback|flat)\b|%\s?off', caseSensitive: false);

  static MessageCategory classify(String messageText, String sender) {
    // 1. OTP: a code keyword, or a "code" mention next to a 4-8 digit number.
    if (_otp.hasMatch(messageText) || (_otpDigits.hasMatch(messageText) && _code.hasMatch(messageText))) {
      return MessageCategory.otp;
    }

    // 2. Banking
    if (_banking.hasMatch(messageText)) return MessageCategory.banking;

    // 3. Promotions
    if (_promo.hasMatch(messageText)) return MessageCategory.promotions;

    // 4. Personal (heuristic: usually sender is a name or phone number, not a shortcode/bulk sender ID)
    if (RegExp(r'^\+?\d+$').hasMatch(sender) || sender.contains(' ') || sender.length > 8) {
      return MessageCategory.personal;
    }

    return MessageCategory.unknown;
  }
}
