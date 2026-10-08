import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/member_widgets.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../device/face_id_sheet.dart';
import '../members/member_profile_screen.dart';
import '../money/receipt_pdf.dart';
import 'admission_screen.dart';

/// The moment after an admission: confetti, the new member ID, and the three things the desk
/// does next (welcome message, receipt, card).
class AdmissionSuccessScreen extends StatelessWidget {
  final AdmissionResult result;

  const AdmissionSuccessScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final m = gym.memberById(result.member.id) ?? result.member;
    final paid = result.payments.fold(0.0, (s, p) => s + p.amount);
    return Scaffold(
      body: GlowBackground(
        child: ConfettiOverlay(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  children: [
                    const Center(child: SuccessBurst(size: 140)),
                    const SizedBox(height: 6),
                    Text('Welcome to the\nUnique family', textAlign: TextAlign.center, style: AppText.display.copyWith(fontSize: 32)).entrance(context, delay: const Duration(milliseconds: 350)),
                    const SizedBox(height: 22),
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      borderColor: AppColors.primary.withValues(alpha: 0.4),
                      child: Row(
                        children: [
                          MemberAvatar(member: m, size: 64, hero: false),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: AppText.title.copyWith(fontSize: 19)),
                                const SizedBox(height: 2),
                                Text(memberCode(m.number), style: AppText.title.copyWith(color: AppColors.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
                                const SizedBox(height: 4),
                                Text('${gym.planById(m.planId)?.name ?? ''} · till ${formatDate(m.endDate)}', style: AppText.small),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).entrance(context, delay: const Duration(milliseconds: 500)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _Figure('Paid', formatMoney(paid), AppColors.text)),
                        const SizedBox(width: 10),
                        Expanded(child: _Figure('Balance due', formatMoney(m.balanceDue), m.balanceDue > 0 ? AppColors.danger : AppColors.text)),
                      ],
                    ).entrance(context, delay: const Duration(milliseconds: 600)),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp, foregroundColor: Colors.white),
                      onPressed: () async {
                        final ok = await openWhatsApp(context, m.phone, gym.messageFor(ReminderKind.welcome, m));
                        if (ok) await gym.logReminder(ReminderKind.welcome, m.id);
                      },
                      icon: const Icon(AppIcons.chat),
                      label: const Text('Send welcome on WhatsApp'),
                    ).entrance(context, delay: const Duration(milliseconds: 700)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (result.receiptNo != null) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                              onPressed: () => shareReceiptPdf(context, result.receiptNo!),
                              icon: const Icon(AppIcons.pdf),
                              label: const Text('Receipt'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                            onPressed: () => showFaceIdSheet(context, m),
                            icon: Icon(m.faceEnrolled ? AppIcons.verified : AppIcons.faceId),
                            label: Text(m.faceEnrolled ? 'Face ID ✓' : 'Face ID'),
                          ),
                        ),
                      ],
                    ).entrance(context, delay: const Duration(milliseconds: 780)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MemberProfileScreen(memberId: m.id))),
                            child: const Text('Open profile'),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdmissionScreen())),
                            child: const Text('Next admission'),
                          ),
                        ),
                      ],
                    ),
                    Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done', style: TextStyle(color: AppColors.muted)))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Figure(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.label.copyWith(fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, style: AppText.headline.copyWith(fontSize: 22, color: color)),
        ]),
      );
}

