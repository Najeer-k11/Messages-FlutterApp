import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/inbox/bloc/hubs_bloc.dart';
import 'package:msgs/features/otp/widgets/otp_card.dart';
import 'package:msgs/ui/ui.dart';

/// Active one-time codes, as a horizontal strip at the top of Chats. Codes are time-sensitive, so
/// they stay on the first tab rather than moving to their own.
class HubsSection extends StatelessWidget {
  const HubsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HubsBloc, HubsState>(
      builder: (context, state) {
        final otps = state is HubsLoaded ? state.activeOtps : const [];
        if (otps.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading('Codes'),
              SizedBox(
                height: 128,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: otps.length,
                  itemBuilder: (context, i) => SpringBuilder(
                    from: 0,
                    value: 1,
                    spring: Motion.pillAppear,
                    child: OtpCard(otpData: otps[i]),
                    builder: (context, t, child) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(offset: Offset(24 * (1 - t), 0), child: child),
                    ),
                  ),
                ),
              ),
              const SectionHeading('Conversations'),
            ],
          ),
        );
      },
    );
  }
}
