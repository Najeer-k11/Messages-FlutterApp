import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:msgs/services/sms/categorization/otp_parser.dart';
import 'package:msgs/ui/ui.dart';

/// A one-time code. OTPs are "not yours" content, so they use the tertiary family.
class OtpCard extends StatelessWidget {
  final OtpData otpData;

  const OtpCard({super.key, required this.otpData});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: LuminousElastic.tile(
        semanticLabel: 'Copy code ${otpData.code} from ${otpData.serviceName}',
        onTap: () {
          HapticFeedback.lightImpact();
          Clipboard.setData(ClipboardData(text: otpData.code));
          showExpressiveSnack(context, 'Copied ${otpData.code}', aboveDock: true);
        },
        child: Container(
          width: 172,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: ShapeDecoration(shape: Shapes.tile, color: c.tertiaryContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShapeBox(
                    size: 30,
                    shape: CookieBorder.cookie4,
                    color: c.tertiary,
                    child: Icon(Icons.key_rounded, size: 16, color: c.onTertiary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      otpData.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.labelLargeEmphasized.copyWith(color: c.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  otpData.code,
                  style: context.type.headlineMediumEmphasized.copyWith(color: c.onTertiaryContainer, letterSpacing: 2),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    otpData.validity != null ? Icons.timer_outlined : Icons.content_copy_rounded,
                    size: 14,
                    color: c.onTertiaryContainer.withValues(alpha: .75),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    otpData.validity != null ? _remaining(otpData.validity!) : 'Tap to copy',
                    style: context.text.labelMedium?.copyWith(color: c.onTertiaryContainer.withValues(alpha: .75)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _remaining(Duration d) => d.inMinutes < 1 ? 'Expires soon' : '${d.inMinutes} min left';
}
