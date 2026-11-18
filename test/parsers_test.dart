import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:msgs/features/banking/widgets/transaction_card.dart';
import 'package:msgs/services/sms/categorization/message_classifier.dart';
import 'package:msgs/services/sms/categorization/otp_parser.dart';
import 'package:msgs/services/sms/categorization/scam_detector.dart';
import 'package:msgs/services/sms/models/read_state_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/services/wallpaper/wallpaper_colors.dart';

void main() {
  group('promotional senders', () {
    test('only the -P suffix is promotional', () {
      expect(SmsRepository.isPromotionalSender('AD-AMAZON-P'), isTrue);
      expect(SmsRepository.isPromotionalSender('VM-PAYTMB-S'), isFalse);
      expect(SmsRepository.isPromotionalSender('AX-PHONPE'), isFalse);
      expect(SmsRepository.isPromotionalSender('+15551234'), isFalse);
    });
  });

  group('MessageClassifier', () {
    test('"pin" inside another word is not an OTP', () {
      expect(
        MessageClassifier.classify('Happy shopping! Your order ships today', 'AMAZON'),
        isNot(MessageCategory.otp),
      );
    });

    test('detects OTPs', () {
      expect(MessageClassifier.classify('Your Swiggy OTP is 482913', 'AXSWIGY'), MessageCategory.otp);
      expect(MessageClassifier.classify('Use PIN 4421 to log in', 'BANK'), MessageCategory.otp);
    });

    test('"hours" is not a rupee amount', () {
      expect(MessageClassifier.classify('See you in 2 hours 12 minutes', '5551234'), isNot(MessageCategory.banking));
    });
  });

  group('OtpParser', () {
    test('prefers the number next to the keyword over dates and accounts', () {
      final otp = OtpParser.extract('On 16-11-2026 for A/c 4455, your OTP is 482913. Valid 10 mins.', 'VM-HDFC');
      expect(otp?.code, '482913');
      expect(otp?.validity, const Duration(minutes: 10));
    });

    test('handles "<code> is your" phrasing', () {
      expect(OtpParser.extract('2026 sale! 771204 is your verification code', 'X')?.code, '771204');
    });
  });

  group('TransactionData', () {
    test('debit followed by "credited to" is a debit', () {
      final t = TransactionData.extract('Rs.2,450.00 debited from A/c XX1234 and credited to AMAZON');
      expect(t?.isCredit, isFalse);
      expect(t?.amount, '2,450.00');
      expect(t?.accountOrEntity, 'A/C …1234');
    });

    test('credit, INR and rupee sign', () {
      expect(TransactionData.extract('INR 15,000 credited to your A/c XX9876')?.isCredit, isTrue);
      expect(TransactionData.extract('₹499 spent on card ending 3321')?.amount, '499');
      expect(TransactionData.extract('₹499 spent on card ending 3321')?.accountOrEntity, 'A/C …3321');
    });

    test('a message without an amount is not a transaction', () {
      expect(TransactionData.extract('Your account statement is ready'), isNull);
    });
  });

  group('parseWallpaperColors', () {
    List<int> tones(int argb) => TonalPalette.fromHct(Hct.fromInt(argb)).asList;

    final payload = <String, Object?>{
      'palettes': {
        'accent1': tones(0xFF3F5AA9),
        'accent2': tones(0xFF5A5D72),
        'accent3': tones(0xFF76546E),
        'neutral1': tones(0xFF77777A),
        'neutral2': tones(0xFF75777F),
      },
    };

    test('builds complete schemes with distinct surface containers', () {
      final s = parseWallpaperColors(payload);
      expect(s.available, isTrue);
      final light = s.light!;
      // The reason dynamic_color was replaced: these must not collapse onto `surface`.
      expect(light.surfaceContainerLow, isNot(light.surface));
      expect(light.surfaceContainerHigh, isNot(light.surfaceContainerLow));
      expect(s.dark!.brightness.name, 'dark');
    });

    test('Android 14 system roles override derived values when they match the wallpaper', () {
      final primaryTone40 = TonalPalette.fromList(tones(0xFF3F5AA9)).get(40);
      final s = parseWallpaperColors({
        ...payload,
        'roles': {
          'light': {'primary': primaryTone40, 'surface_container': 0xFF445566},
          'dark': <String, int>{},
        },
      });
      expect(s.light!.primary.toARGB32(), primaryTone40);
      expect(s.light!.surfaceContainer.toARGB32(), 0xFF445566);
    });

    test('stale vendor roles (a different hue from the wallpaper) are ignored', () {
      final s = parseWallpaperColors({
        ...payload,
        'roles': {
          // A stock green primary while the wallpaper palette is blue-violet.
          'light': {'primary': 0xFF2E7D32, 'surface_container': 0xFF445566},
          'dark': <String, int>{},
        },
      });
      expect(s.light!.primary.toARGB32(), isNot(0xFF2E7D32));
      expect(s.light!.surfaceContainer.toARGB32(), isNot(0xFF445566));
    });

    test('no palettes means no wallpaper scheme', () {
      expect(parseWallpaperColors({}).available, isFalse);
    });
  });

  group('ReadStateModel', () {
    final t0 = DateTime.utc(2026, 11, 16, 10);
    ReadStateModel state({DateTime? readUpTo, DateTime? unreadFrom}) => ReadStateModel()
      ..address = '5551234'
      ..readUpTo = readUpTo
      ..unreadFrom = unreadFrom;

    test('a read conversation stays read even if the provider still says unread', () {
      final s = state(readUpTo: t0);
      expect(s.isRead(t0.subtract(const Duration(minutes: 5)), providerRead: false), isTrue);
      expect(s.isRead(t0, providerRead: false), isTrue);
    });

    test('messages arriving after the read stay unread', () {
      expect(state(readUpTo: t0).isRead(t0.add(const Duration(seconds: 1)), providerRead: false), isFalse);
    });

    test('mark as unread wins over the provider read flag', () {
      expect(state(unreadFrom: t0).isRead(t0, providerRead: true), isFalse);
      expect(state(unreadFrom: t0).isRead(t0.subtract(const Duration(minutes: 1)), providerRead: true), isTrue);
    });

    test('without a record the provider decides', () {
      expect(state().isRead(t0, providerRead: true), isTrue);
      expect(state().isRead(t0, providerRead: false), isFalse);
    });
  });

  group('ScamDetector', () {
    test('flags fake KYC and parcel texts with links from phone numbers', () {
      expect(
        ScamDetector.isSuspicious('Dear customer your KYC update pending, account will be blocked today. https://sbi-kyc.co/x', '+919812345678'),
        isTrue,
      );
      expect(ScamDetector.isSuspicious('Your parcel is on hold. Pay fee: bit.ly/3xYz', '+447700900123'), isTrue);
    });

    test('flags IP, punycode and throwaway-domain links from anyone', () {
      expect(ScamDetector.isSuspicious('Login now http://192.168.4.20/login', 'AX-BANK'), isTrue);
      expect(ScamDetector.isSuspicious('Refund ready: https://xn--pypal-4ve.com/r', 'VM-SHOPS'), isTrue);
      expect(ScamDetector.isSuspicious('Track at https://ups-track.top/a1', '+15551234567'), isTrue);
    });

    test('leaves normal messages alone', () {
      expect(ScamDetector.isSuspicious('Rs 500 debited from a/c XX12. Not you? Call 1800', 'AX-HDFCBK'), isFalse);
      expect(ScamDetector.isSuspicious('Update KYC at https://hdfcbk.io/k', 'AX-HDFCBK-S'), isFalse);
      expect(ScamDetector.isSuspicious('look at this https://youtube.com/watch?v=1', '+919812345678'), isFalse);
      expect(ScamDetector.isSuspicious('Congratulations on the new job!', '+919812345678'), isFalse);
    });

    test('never flags saved contacts', () {
      expect(
        ScamDetector.isSuspicious('claim your prize bit.ly/x', '+919812345678', knownContact: true),
        isFalse,
      );
    });
  });
}
