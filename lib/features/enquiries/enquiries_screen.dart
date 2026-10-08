import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../admission/admission_screen.dart';
import 'enquiry_sheet.dart';

/// Walk-in and phone enquiries as a simple pipeline: new, follow-up, on trial, joined, not interested.
class EnquiriesScreen extends StatefulWidget {
  const EnquiriesScreen({super.key});

  @override
  State<EnquiriesScreen> createState() => _EnquiriesScreenState();
}

class _EnquiriesScreenState extends State<EnquiriesScreen> {
  EnquiryStatus? _status; // null = all open ones

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final list = _status == null ? gym.enquiriesWith(openOnly: true) : gym.enquiriesWith(status: _status);
    final all = gym.enquiries;
    final joined = all.where((e) => e.status == EnquiryStatus.converted).length;
    final closed = all.where((e) => !e.status.isOpen).length;
    final due = gym.followUpsDue;

    return SubPage(
      title: 'Enquiries',
      subtitle: '${gym.enquiriesWith(openOnly: true).length} open · ${due.length} to follow up today',
      floatingAction: FloatingActionButton.extended(
        heroTag: 'enquiry-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => showEnquirySheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ENQUIRY', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              ProgressRing(
                value: closed == 0 ? 0 : joined / closed,
                size: 84,
                stroke: 8,
                color: AppColors.success,
                child: Text(closed == 0 ? '-' : '${(joined / closed * 100).round()}%', style: AppText.headline.copyWith(fontSize: 20)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Conversion', style: AppText.title),
                  const SizedBox(height: 2),
                  Text('$joined of $closed decided enquiries joined the gym.', style: AppText.small.copyWith(color: AppColors.muted)),
                ]),
              ),
            ]),
          ).entrance(context),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _chip(null, 'Open', gym.enquiriesWith(openOnly: true).length),
              for (final s in EnquiryStatus.values) _chip(s, s.label, gym.enquiriesWith(status: s).length),
            ]),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const EmptyState(icon: Icons.contact_phone_rounded, title: 'No enquiries here', subtitle: 'Save walk-ins and calls so every lead gets a follow-up.')
          else
            for (var i = 0; i < list.length; i++) _EnquiryCard(enquiry: list[i]).entrance(context, index: i),
        ],
      ),
    );
  }

  Widget _chip(EnquiryStatus? s, String label, int count) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: _status == s,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            setState(() => _status = s);
          },
          label: Text('$label  $count'),
          labelStyle: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w700, color: _status == s ? Colors.white : AppColors.text),
        ),
      );
}

class _EnquiryCard extends StatelessWidget {
  final Enquiry enquiry;

  const _EnquiryCard({required this.enquiry});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final e = enquiry;
    final overdue = e.nextFollowUp != null && e.status.isOpen && !dateOnly(e.nextFollowUp!).isAfter(gym.today);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => showEnquirySheet(context, enquiry: e),
        borderColor: overdue ? AppColors.warning.withValues(alpha: 0.4) : null,
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(radius: 21, backgroundColor: e.status.color.withValues(alpha: 0.16), child: Text(initials(e.name), style: AppText.small.copyWith(color: e.status.color, fontWeight: FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.name, style: AppText.title.copyWith(fontSize: 16)),
                  Text('${e.source.label} · ${relativeDay(e.createdAt, gym.today)}${gym.planById(e.planId) == null ? '' : ' · ${gym.planById(e.planId)!.name}'}', style: AppText.small.copyWith(color: AppColors.muted)),
                ]),
              ),
              StatusPill(e.status.label, color: e.status.color),
            ]),
            if (e.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(e.notes, style: AppText.small),
            ],
            const SizedBox(height: 6),
            Row(children: [
              if (e.nextFollowUp != null && e.status.isOpen)
                StatusPill(overdue ? 'Follow up ${relativeDay(e.nextFollowUp!, gym.today).toLowerCase()}' : 'Next: ${relativeDay(e.nextFollowUp!, gym.today)}',
                    color: overdue ? AppColors.warning : AppColors.muted, icon: Icons.event_rounded),
              const Spacer(),
              IconButton(tooltip: 'Call', icon: const Icon(Icons.call_rounded, size: 20), onPressed: () => callNumber(context, e.phone)),
              IconButton(
                tooltip: 'WhatsApp follow-up',
                icon: const Icon(Icons.chat_rounded, size: 20, color: AppColors.whatsapp),
                onPressed: () async {
                  final ok = await openWhatsApp(context, e.phone, gym.enquiryMessage(e));
                  if (ok) await gym.logReminder(ReminderKind.followUp, e.id);
                },
              ),
              if (e.status.isOpen)
                TextButton.icon(
                  onPressed: () => openPage(context, AdmissionScreen(enquiryId: e.id)),
                  icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                  label: const Text('Admit'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
