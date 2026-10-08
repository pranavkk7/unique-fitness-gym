import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../money/payment_sheet.dart';

/// What members say: a rating out of five with a category and comment. Low ratings stay at the
/// top until someone replies and marks them resolved.
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final avg = gym.averageRating();
    final all = gym.feedback.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final open = all.where((f) => f.needsAction).toList();
    final rest = all.where((f) => !f.needsAction).toList();
    final counts = List.generate(5, (i) => all.where((f) => f.rating == 5 - i).length);

    return SubPage(
      title: 'Feedback',
      subtitle: '${all.length} responses · ${open.length} need action',
      floatingAction: FloatingActionButton.extended(
        heroTag: 'feedback-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => showFeedbackSheet(context),
        icon: const Icon(AppIcons.review),
        label: const Text('Add feedback', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Column(children: [
                CountUp(value: avg ?? 0, format: (v) => avg == null ? '—' : v.toStringAsFixed(1), style: AppText.stat.copyWith(fontSize: 48)),
                Stars(rating: (avg ?? 0).round(), size: 16),
                const SizedBox(height: 4),
                Text('Last 90 days', style: AppText.label.copyWith(fontSize: 9)),
              ]),
              const SizedBox(width: 22),
              Expanded(
                child: Column(children: [
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(children: [
                        SizedBox(width: 14, child: Text('${5 - i}', style: AppText.small.copyWith(fontWeight: FontWeight.w800))),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: all.isEmpty ? 0 : counts[i] / all.length),
                            duration: Motion.reduced(context) ? Duration.zero : Motion.chart + Motion.stagger * i,
                            curve: Motion.settle,
                            builder: (_, v, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: AppColors.surfaceHigher, color: i < 2 ? AppColors.success : i == 2 ? AppColors.warning : AppColors.danger),
                            ),
                          ),
                        ),
                        SizedBox(width: 26, child: Text('${counts[i]}', textAlign: TextAlign.right, style: AppText.small.copyWith(color: AppColors.muted))),
                      ]),
                    ),
                ]),
              ),
            ]),
          ).entrance(context),
          if (all.isNotEmpty) ...[
            const SectionHeader('By topic'),
            AppCard(
              child: RankedBars(
                color: AppColors.categorical[3],
                items: [
                  for (final c in FeedbackCategory.values)
                    if (all.any((f) => f.category == c))
                      (c.label, all.where((f) => f.category == c).length.toDouble(), '${(all.where((f) => f.category == c).fold(0, (s, f) => s + f.rating) / all.where((f) => f.category == c).length).toStringAsFixed(1)} / 5'),
                ],
              ),
            ),
          ],
          if (open.isNotEmpty) ...[
            const SectionHeader('Needs action'),
            for (final f in open) Padding(padding: const EdgeInsets.only(bottom: 8), child: _FeedbackCard(entry: f)),
          ],
          if (rest.isNotEmpty) ...[
            const SectionHeader('All feedback'),
            for (var i = 0; i < rest.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: _FeedbackCard(entry: rest[i])).entrance(context, index: i < 10 ? i : 10),
          ],
          if (all.isEmpty) const EmptyState(icon: AppIcons.review, title: 'No feedback yet', subtitle: 'Ask members how the gym is doing and note it here.'),
        ],
      ),
    );
  }
}

/// A row of five stars, filled up to [rating].
class Stars extends StatelessWidget {
  final int rating;
  final double size;

  const Stars({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$rating out of 5 stars',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 1; i <= 5; i++) Icon(i <= rating ? AppIcons.star : AppIcons.starOutline, size: size, color: i <= rating ? AppColors.warning : AppColors.muted),
        ]),
      );
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackEntry entry;

  const _FeedbackCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final f = entry;
    final member = gym.memberById(f.memberId);
    return AppCard(
      radius: 20,
      borderColor: f.needsAction ? AppColors.danger.withValues(alpha: 0.45) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Stars(rating: f.rating),
          const SizedBox(width: 8),
          StatusPill(f.category.label, color: AppColors.categorical[f.category.index % 4], icon: f.category.icon),
          const Spacer(),
          Text(relativeDay(f.createdAt, gym.today), style: AppText.small.copyWith(color: AppColors.muted)),
        ]),
        if (f.comment.isNotEmpty) ...[const SizedBox(height: 8), Text('“${f.comment}”', style: AppText.body)],
        const SizedBox(height: 6),
        Text(f.name, style: AppText.small.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        if (f.resolved && f.response.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(AppIcons.reply, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Expanded(child: Text(f.response, style: AppText.small.copyWith(color: AppColors.success))),
          ]),
        ],
        if (f.needsAction)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 4, children: [
              if (member != null)
                TextButton.icon(
                  onPressed: () => openWhatsApp(context, member.phone, 'Hi ${member.firstName}, thank you for your feedback about ${f.category.label.toLowerCase()} at ${gym.settings.gymName}. '),
                  icon: const Icon(AppIcons.chat, size: 18, color: AppColors.whatsapp),
                  label: const Text('Reply'),
                ),
              TextButton.icon(onPressed: () => _resolve(context), icon: const Icon(AppIcons.check, size: 18), label: const Text('Resolve')),
            ]),
          ),
      ]),
    );
  }

  Future<void> _resolve(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('What was done?'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Added a second evening batch')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(d, true), child: const Text('Resolve')),
        ],
      ),
    );
    if (ok == true && context.mounted) await context.read<GymProvider>().resolveFeedback(entry.id, response: ctrl.text);
    ctrl.dispose();
  }
}

/// Notes a member's feedback: stars, topic and comment.
Future<void> showFeedbackSheet(BuildContext context, {Member? member}) => showAppSheet<void>(context, builder: (_) => _FeedbackSheet(member: member));

class _FeedbackSheet extends StatefulWidget {
  final Member? member;

  const _FeedbackSheet({this.member});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  late Member? _member = widget.member;
  final _name = TextEditingController();
  final _comment = TextEditingController();
  int _rating = 0;
  FeedbackCategory _category = FeedbackCategory.other;

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader('Feedback', subtitle: 'How is the gym doing?'),
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  iconSize: 40,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _rating = i);
                  },
                  icon: AnimatedScale(
                    scale: i <= _rating ? 1.1 : 1,
                    duration: Motion.fast,
                    curve: Motion.pop,
                    child: Icon(i <= _rating ? AppIcons.star : AppIcons.starOutline, color: i <= _rating ? AppColors.warning : AppColors.muted),
                  ),
                ),
            ]),
          ),
          const FieldLabel('About'),
          ChoiceChips<FeedbackCategory>(options: FeedbackCategory.values, selected: _category, labelOf: (c) => c.label, iconOf: (c) => c.icon, onSelected: (c) => setState(() => _category = c)),
          const SizedBox(height: 16),
          TextField(controller: _comment, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What did they say?')),
          const SizedBox(height: 12),
          PickerField(
            label: 'Member (optional)',
            value: _member?.name,
            icon: AppIcons.person,
            onTap: () async {
              final m = await pickMember(context, title: 'Whose feedback?');
              if (m != null) setState(() => _member = m);
            },
            onClear: () => setState(() => _member = null),
          ),
          if (_member == null) ...[const SizedBox(height: 12), TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name (optional)'))],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _rating == 0
                ? null
                : () async {
                    await context.read<GymProvider>().addFeedback(memberId: _member?.id, name: _member?.name ?? _name.text, rating: _rating, category: _category, comment: _comment.text);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    showMessage(context, _rating <= 3 ? 'Saved. It is on the "Needs action" list.' : 'Thanks, feedback saved.');
                  },
            child: Text(_rating == 0 ? 'Tap a star' : 'Save feedback'),
          ),
        ],
      ),
    );
  }
}
