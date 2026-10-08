import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/pin_pad.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../providers/gym_provider.dart';
import '../enquiries/enquiries_screen.dart';
import '../money/expenses_screen.dart';
import '../money/payments_screen.dart';
import '../reports/revenue_screen.dart';
import '../device/device_screen.dart';
import '../desk/close_day_screen.dart';
import '../desk/day_pass_sheet.dart';
import '../engagement/feedback_screen.dart';
import '../engagement/progress_reports_screen.dart';
import '../engagement/training_plans_screen.dart';
import '../money/offers_screen.dart';
import '../shop/shop_screen.dart';
import '../training/pt_screen.dart';
import 'about_screen.dart';
import 'classes_screen.dart';
import 'plans_screen.dart';
import 'settings_screen.dart';
import 'templates_screen.dart';
import 'trainers_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final s = gym.settings;

    Future<void> owner(Widget page) async {
      if (await ensureOwner(context) && context.mounted) openPage(context, page);
    }

    final groups = <(String, List<(IconData, String, String, Color, VoidCallback, bool)>)>[
      ('Business', [
        (Icons.insights_rounded, 'Revenue & reports', 'Income, profit, renewals, busy hours', AppColors.primary, () => owner(const RevenueScreen()), true),
        (Icons.receipt_long_rounded, 'Payments', 'Every receipt, by day', AppColors.success, () => openPage(context, const PaymentsScreen()), false),
        (Icons.account_balance_wallet_rounded, 'Expenses', 'Rent, salaries, bills', AppColors.ember, () => owner(const ExpensesScreen()), true),
        (Icons.storefront_rounded, 'Shop & stock', gym.lowStock.isEmpty ? '${gym.products.length} items' : '${gym.lowStock.length} items running low', AppColors.categorical[1], () => openPage(context, const ShopScreen()), false),
        (Icons.sports_rounded, 'Personal training', '${gym.ptPackages.where((p) => p.isActive(gym.today)).length} running packages · commissions', AppColors.categorical[0], () => openPage(context, const PtScreen()), false),
        (Icons.confirmation_number_rounded, 'Offers & referrals', '${gym.offers.where((o) => o.active).length} codes · referral reward ${gym.settings.referralRewardDays} days', AppColors.primaryBright, () => owner(const OffersScreen()), true),
      ]),
      ('Front desk', [
        (Icons.contact_phone_rounded, 'Enquiries', '${gym.followUpsDue.length} follow-ups due', AppColors.categorical[3], () => openPage(context, const EnquiriesScreen()), false),
        (Icons.lock_clock_rounded, 'Close the day', gym.closeFor(gym.today) == null ? 'Count the cash, send the report' : 'Closed today · tap to update', AppColors.whatsapp, () => openPage(context, const CloseDayScreen()), false),
        (Icons.confirmation_number_outlined, 'Day pass & trial', 'Walk-ins who are not members yet', AppColors.categorical[1], () => showDayPassSheet(context), false),
        (Icons.event_note_rounded, 'Classes & batches', '${gym.classes.length} weekly classes · ${gym.classes.fold(0, (s, c) => s + c.memberIds.length)} enrolled', AppColors.categorical[0], () => openPage(context, const ClassesScreen()), false),
      ]),
      ('Members', [
        (Icons.insights_rounded, 'Progress reports', 'Monthly report for each member on WhatsApp', AppColors.categorical[2], () => openPage(context, const ProgressReportsScreen()), false),
        (Icons.fitness_center_rounded, 'Workout & diet plans', '${gym.trainingPlans.length} templates · share as PDF', AppColors.primary, () => openPage(context, const TrainingPlansScreen()), false),
        (Icons.rate_review_rounded, 'Feedback', gym.averageRating() == null ? 'What members say' : 'Rated ${gym.averageRating()!.toStringAsFixed(1)} / 5 · ${gym.feedback.where((f) => f.needsAction).length} need action', AppColors.warning, () => openPage(context, const FeedbackScreen()), false),
      ]),
      ('Setup', [
        (Icons.face_retouching_natural_rounded, 'Face ID device', 'eSSL door terminal · sync and door rules', AppColors.categorical[0], () => owner(const DeviceScreen()), true),
        (Icons.card_membership_rounded, 'Plans & pricing', '${gym.activePlans.length} plans on offer', AppColors.primaryBright, () => owner(const PlansScreen()), true),
        (Icons.sports_rounded, 'Trainers & staff', '${gym.trainers.length} on the team', AppColors.categorical[2], () => openPage(context, const TrainersScreen()), false),
        (Icons.edit_note_rounded, 'Message templates', 'WhatsApp reminder wording', AppColors.whatsapp, () => openPage(context, const TemplatesScreen()), false),
        (Icons.settings_rounded, 'Settings & backup', 'Gym details, PIN, backup', AppColors.textSecondary, () => owner(const SettingsScreen()), true),
      ]),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 140),
      children: [
        RevealText('MORE', style: AppText.display),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const BrandLogo(height: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.gymName.toUpperCase(), style: AppText.headline.copyWith(fontSize: 21)),
                if (s.tagline.isNotEmpty) Text(s.tagline.toUpperCase(), style: AppText.label.copyWith(fontSize: 9.5, letterSpacing: 1.6)),
                Text('${s.branchName} branch', style: AppText.small.copyWith(color: AppColors.primaryBright, fontWeight: FontWeight.w800)),
                if (s.address.isNotEmpty) Text(s.address, style: AppText.small.copyWith(color: AppColors.muted), maxLines: 2),
                Text([s.phone, s.altPhone].where((p) => p.isNotEmpty).join(' · '), style: AppText.small.copyWith(color: AppColors.muted)),
              ]),
            ),
          ]),
        ).entrance(context, index: 1),
        for (final (title, items) in groups) ...[
          SectionHeader(title),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var i = 0; i < items.length; i++)
                ListTile(
                  onTap: items[i].$5,
                  leading: IconBadge(items[i].$1, color: items[i].$4, size: 40),
                  title: Text(items[i].$2),
                  subtitle: Text(items[i].$3),
                  trailing: items[i].$6 && !gym.ownerUnlocked ? const Icon(Icons.lock_rounded, size: 18, color: AppColors.muted) : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ),
            ]),
          ).entrance(context, index: 2),
        ],
        const SizedBox(height: 30),
        const _DeveloperCredit(),
      ],
    );
  }
}

/// The one place the developer is credited: name, GitHub, and the About page.
class _DeveloperCredit extends StatelessWidget {
  const _DeveloperCredit();

  @override
  Widget build(BuildContext context) {
    final handle = Uri.parse(AboutScreen.github).pathSegments.first;
    return Column(children: [
      Row(children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('DESIGNED & DEVELOPED BY', style: AppText.label.copyWith(fontSize: 9.5, letterSpacing: 2.4)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ]),
      const SizedBox(height: 6),
      Text(AboutScreen.developer.toUpperCase(), style: AppText.headline.copyWith(fontSize: 24, color: AppColors.primaryBright)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        _CreditButton(icon: Icons.code_rounded, label: 'github.com/$handle', onTap: () => openLink(context, AboutScreen.github)),
        _CreditButton(icon: Icons.info_outline_rounded, label: 'About this app', onTap: () => openPage(context, const AboutScreen())),
      ]),
      const SizedBox(height: 10),
      Text('Front desk app v${AboutScreen.version}', style: AppText.small.copyWith(color: AppColors.muted, fontSize: 11.5)),
    ]);
  }
}

class _CreditButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CreditButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderStrong)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: AppText.small.copyWith(color: AppColors.text, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
