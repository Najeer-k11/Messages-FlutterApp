/// On-device heuristics for scam texts (phishing links, fake KYC / parcel / prize messages).
///
/// Deliberately conservative: a warning on a real bank alert teaches people to ignore warnings.
/// Messages from saved contacts are never flagged.
class ScamDetector {
  ScamDetector._();

  // Links with or without a scheme ("http://x", "www.x", or a bare "x.xyz/abc").
  static final _link = RegExp(
    r'\b(?:https?://|www\.)\S+|\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}/\S*',
    caseSensitive: false,
  );

  static final _ipHost = RegExp(r'^(?:\d{1,3}\.){3}\d{1,3}$');

  static const _shorteners = {
    'bit.ly', 'tinyurl.com', 'cutt.ly', 'is.gd', 'rb.gy', 't.ly', 'shorturl.at', 'tiny.cc', 'ow.ly',
    'rebrand.ly', 'v.gd', 's.id', 'shorturl.gg', 'surl.li', 'goo.su', 'bitly.ws', 'u.to', 'clck.ru',
  };

  /// Top-level domains common in phishing and rare in genuine service texts.
  static const _riskyTlds = {
    'xyz', 'top', 'click', 'link', 'icu', 'buzz', 'tk', 'ml', 'ga', 'cf', 'gq', 'cfd', 'sbs', 'rest',
    'zip', 'mov', 'quest', 'cyou', 'bond', 'lol', 'monster', 'country', 'support', 'live', 'vip',
  };

  /// Pressure, prize and fake-service wording.
  static final _bait = RegExp(
    r'\b(?:kyc|pan\s*card|aadhaa?r)\b.{0,40}\b(?:updat|verif|expir|block|suspend)'
    r'|\b(?:account|a/c|card|wallet|sim)\b.{0,30}\b(?:will\s+be\s+)?(?:blocked|suspended|deactivated|frozen|closed)\b'
    r'|\b(?:electricity|power)\b.{0,40}\b(?:disconnect|cut\s*off)'
    r'|\b(?:you\s+have\s+won|congratulations|lottery|lucky\s+draw|jackpot)\b'
    r'|\bclaim\b.{0,30}\b(?:prize|reward|refund|gift|cashback)\b'
    r'|\b(?:parcel|package|shipment|delivery)\b.{0,40}\b(?:held|on\s+hold|failed|pending|unpaid|suspended)\b'
    r'|\b(?:unpaid|outstanding)\b.{0,20}\b(?:toll|fine|challan|bill)\b'
    r'|\b(?:reward|loyalty)\s+points?\b.{0,30}\bexpir'
    r'|\bverify\s+your\s+(?:account|identity|details)\b'
    r'|\b(?:work\s+from\s+home|part[\s-]?time\s+job)\b.{0,60}\b(?:earn|daily|income)\b',
    caseSensitive: false,
  );

  /// Personal-looking phone number (not a short code or DLT sender ID).
  static final _phone = RegExp(r'^\+?\d{8,}$');

  /// The hosts of every link in [text], lower-cased.
  static Iterable<String> _hosts(String text) sync* {
    for (final m in _link.allMatches(text)) {
      var url = m.group(0)!.toLowerCase();
      url = url.replaceFirst(RegExp(r'^https?://'), '');
      final end = url.indexOf(RegExp(r'[/?#]'));
      var host = end < 0 ? url : url.substring(0, end);
      if (host.contains('@')) host = host.substring(host.lastIndexOf('@') + 1); // user@host trick
      host = host.split(':').first.replaceAll(RegExp(r'[.,;!)]+$'), '');
      if (host.startsWith('www.')) host = host.substring(4);
      if (host.isNotEmpty) yield host;
    }
  }

  static bool _riskyHost(String host) {
    if (_ipHost.hasMatch(host) || host.contains('xn--')) return true;
    return _riskyTlds.contains(host.split('.').last);
  }

  /// Whether a received message looks like a scam. [knownContact] is true for saved contacts.
  static bool isSuspicious(String body, String sender, {bool knownContact = false}) {
    if (knownContact || body.isEmpty) return false;
    final hosts = _hosts(body).toList();
    final bait = _bait.hasMatch(body);

    // An IP address, punycode or throwaway domain is a red flag from anyone.
    if (hosts.any(_riskyHost)) return true;

    // Registered business sender IDs (e.g. "AX-HDFCBK") can't easily be spoofed, and real
    // banks do send KYC reminders with short links, so the rest only applies to phone numbers.
    if (!_phone.hasMatch(sender.replaceAll(RegExp(r'[\s\-()]'), ''))) return false;

    if (hosts.isNotEmpty && (bait || hosts.any(_shorteners.contains))) return true;
    return false;
  }
}
