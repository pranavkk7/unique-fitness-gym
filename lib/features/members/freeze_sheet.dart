import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';

/// Pauses a membership (travel, illness, exams). The end date moves out by the same number of days.
Future<void> showFreezeSheet(BuildContext context, Member member) => showAppSheet<void>(context, builder: (_) => _FreezeSheet(member: member));

class _FreezeSheet extends StatefulWidget {
  final Member member;

  const _FreezeSheet({required this.member});

  @override
  State<_FreezeSheet> createState() => _FreezeSheetState();
}

class _FreezeSheetState extends State<_FreezeSheet> {
  double _days = 15;
  String _reason = 'Travelling';
  static const _reasons = ['Travelling', 'Illness or injury', 'Exams', 'Work', 'Other'];

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final newEnd = widget.member.endDate.add(Duration(days: _days.round()));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader('Freeze membership', subtitle: '${widget.member.firstName} keeps every paid day. Check-ins are paused while frozen.'),
          Row(
            children: [
              const Icon(AppIcons.freeze, color: AppColors.frozen, size: 30),
              const SizedBox(width: 12),
              Text('${_days.round()} days', style: AppText.display.copyWith(fontSize: 40)),
            ],
          ),
          Slider(value: _days, min: 1, max: 90, divisions: 89, label: '${_days.round()} days', onChanged: (v) => setState(() => _days = v)),
          const FieldLabel('Reason'),
          ChoiceChips<String>(options: _reasons, selected: _reason, labelOf: (r) => r, onSelected: (r) => setState(() => _reason = r)),
          const SizedBox(height: 18),
          Text('From today till ${formatDate(gym.today.add(Duration(days: _days.round() - 1)))}. New end date ${formatDate(newEnd)}.', style: AppText.body),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.frozen, foregroundColor: Colors.black),
            onPressed: () async {
              try {
                await gym.freeze(widget.member.id, days: _days.round(), reason: _reason);
                if (context.mounted) {
                  Navigator.pop(context);
                  showMessage(context, 'Frozen for ${_days.round()} days. Ends ${formatDate(newEnd)} now.');
                }
              } on StateError catch (e) {
                if (context.mounted) showMessage(context, e.message);
              }
            },
            icon: const Icon(AppIcons.freeze),
            label: const Text('Freeze'),
          ),
        ],
      ),
    );
  }
}
