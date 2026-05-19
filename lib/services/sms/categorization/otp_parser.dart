class OtpData {
  final String code;
  final String serviceName;
  final Duration? validity;

  OtpData({
    required this.code,
    required this.serviceName,
    this.validity,
  });
}

class OtpParser {
  // Common regex for 4 to 8 digit OTPs
  static final RegExp _otpRegExp = RegExp(r'\b(?:\d{4,8})\b');

  static OtpData? extract(String messageText, String sender) {
    // 1. Extract OTP
    final match = _otpRegExp.firstMatch(messageText);
    if (match == null) return null;
    
    final code = match.group(0)!;

    // 2. Extract Service Name (Fallback to sender if not explicitly found in common patterns)
    String serviceName = _cleanSenderName(sender);

    // Try to find phrases like "from Amazon" or "your Swiggy code"
    final serviceMatch = RegExp(r'(?:from|your|by)\s+([A-Za-z]+)\b', caseSensitive: false).firstMatch(messageText);
    if (serviceMatch != null && serviceMatch.group(1) != null) {
      final potentialName = serviceMatch.group(1)!;
      // Filter out common words
      if (!['otp', 'code', 'verification', 'account'].contains(potentialName.toLowerCase())) {
        serviceName = potentialName;
      }
    }

    // 3. Extract Validity (e.g. "valid for 10 minutes")
    Duration? validity;
    final minsMatch = RegExp(r'(\d+)\s*min(?:ute)?s?', caseSensitive: false).firstMatch(messageText);
    if (minsMatch != null && minsMatch.group(1) != null) {
      validity = Duration(minutes: int.parse(minsMatch.group(1)!));
    }

    return OtpData(
      code: code,
      serviceName: serviceName.isNotEmpty ? _capitalize(serviceName) : 'Unknown',
      validity: validity,
    );
  }

  static String _cleanSenderName(String sender) {
    // Senders often look like "VM-SWIGGY" or "AD-AMAZON"
    final parts = sender.split('-');
    if (parts.length > 1) {
      return parts.last;
    }
    return sender;
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
