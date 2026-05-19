import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/inbox/bloc/hubs_bloc.dart';
import 'package:msgs/features/otp/widgets/otp_card.dart';
import 'package:msgs/features/banking/widgets/transaction_card.dart';

class HubsSection extends StatelessWidget {
  const HubsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<HubsBloc, HubsState>(
      builder: (context, state) {
        if (state is! HubsLoaded) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final activeOtps = state.activeOtps;
        final recentTransactions = state.recentTransactions;

        if (activeOtps.isEmpty && recentTransactions.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeOtps.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      'Active OTPs',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ),
                      itemCount: activeOtps.length,
                      itemBuilder: (context, index) {
                        return OtpCard(
                              otpData: activeOtps[index],
                            )
                            .animate()
                            .fadeIn(delay: (30 * index).ms)
                            .slideX(begin: 0.2, end: 0);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (recentTransactions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      'Recent Transactions',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ),
                      itemCount: recentTransactions.length,
                      itemBuilder: (context, index) {
                        return TransactionCard(
                              data: recentTransactions[index],
                            )
                            .animate()
                            .fadeIn(delay: (30 * index).ms)
                            .slideX(begin: 0.2, end: 0);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
