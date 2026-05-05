import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import '../controllers/loyalty_points_controller.dart';

class LoyaltyPointsView extends StatefulWidget {
  const LoyaltyPointsView({super.key});

  @override
  State<LoyaltyPointsView> createState() => _LoyaltyPointsViewState();
}

class _LoyaltyPointsViewState extends State<LoyaltyPointsView> {
  late final LoyaltyPointsController controller;

  @override
  void initState() {
    super.initState();
    controller = LoyaltyPointsController();
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Row(
            children: [
              const Icon(CupertinoIcons.chevron_back, color: Color(0xFFB48648)),
              const SizedBox(width: 2),
              Text(S.of(context).back, style: const TextStyle(color: Color(0xFFB48648))),
            ],
          ),
        ),
        middle: Text(
          S.of(context).loyaltyPoints,
          style: context.cupertinoTextTheme.textStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: ValueListenableBuilder<SLoadingState<int>>(
          valueListenable: controller,
          builder: (context, value, child) {
            return VAsyncWidgetsBuilder(
              loadingState: value.loadingState,
              onRefresh: controller.getLoyaltyPoints,
              successWidget: () => _buildSuccessWidget(context, value.data),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSuccessWidget(BuildContext context, int points) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Main Points Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFB48648),
                  Color(0xFF8B6914),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFB48648).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  S.of(context).yourLoyaltyPoints,
                  style: context.cupertinoTextTheme.textStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$points',
                  style: context.cupertinoTextTheme.textStyle.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  S.of(context).points,
                  style: context.cupertinoTextTheme.textStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // How to Earn Points Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.isDark
                  ? CupertinoColors.secondarySystemBackground
                  : CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).howToEarnPoints,
                  style: context.cupertinoTextTheme.textStyle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                _buildEarnPointsItem(
                  context,
                  Icons.person_add,
                  S.of(context).signUp,
                  '10 ${S.of(context).points}',
                  S.of(context).earnPointsSignUpDesc,
                ),
                const SizedBox(height: 16),
                _buildEarnPointsItem(
                  context,
                  Icons.group_add,
                  S.of(context).joinGroup,
                  '5 ${S.of(context).points}',
                  S.of(context).earnPointsJoinGroupDesc,
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Redeem Button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              onPressed: () => _showRedeemModal(context),
              color: const Color(0xFFB48648),
              borderRadius: BorderRadius.circular(12),
              child: Text(
                S.of(context).redeemYourPoints,
                style: context.cupertinoTextTheme.textStyle.copyWith(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnPointsItem(
    BuildContext context,
    IconData icon,
    String title,
    String points,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFB48648).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: const Color(0xFFB48648),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: context.cupertinoTextTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    points,
                    style: context.cupertinoTextTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB48648),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: context.cupertinoTextTheme.textStyle.copyWith(
                  fontSize: 14,
                  color: context.isDark
                      ? CupertinoColors.secondaryLabel
                      : CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRedeemModal(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Coming Soon'),
          content: const Text('You will be able to redeem your points soon!'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
