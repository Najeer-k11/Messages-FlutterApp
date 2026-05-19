enum MessageCategory { otp, banking, promotions, personal, spam, unknown }

class MessageClassifier {
  static const _otpKeywords = ['otp', 'verification code', 'pin', 'code is'];
  static const _bankingKeywords = ['debited', 'credited', 'a/c', 'account', 'upi', 'transaction'];
  static const _promoKeywords = ['offer', 'discount', 'sale', 'cashback', 'flat', '% off'];

  static MessageCategory classify(String messageText, String sender) {
    final lowerText = messageText.toLowerCase();

    // 1. OTP detection
    if (_otpKeywords.any((k) => lowerText.contains(k)) || RegExp(r'\b\d{4,6}\b').hasMatch(lowerText) && (lowerText.contains('code') || lowerText.contains('otp'))) {
      return MessageCategory.otp;
    }

    // 2. Banking detection
    if (_bankingKeywords.any((k) => lowerText.contains(k)) || RegExp(r'rs\.?\s?\d+').hasMatch(lowerText)) {
      return MessageCategory.banking;
    }

    // 3. Promotions detection
    if (_promoKeywords.any((k) => lowerText.contains(k))) {
      return MessageCategory.promotions;
    }

    // 4. Personal (heuristic: usually sender is a name or phone number, not a shortcode/bulk sender ID)
    if (RegExp(r'^\+?\d+$').hasMatch(sender) || sender.contains(' ') || sender.length > 8) {
      return MessageCategory.personal;
    }

    return MessageCategory.unknown;
  }
}
