import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/member_widgets.dart';
import '../../core/widgets/pin_pad.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../members/member_profile_screen.dart';

class TrainersScreen extends StatelessWidget {
  const TrainersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    return SubPage(
      title: 'Trainers & staff',
      floatingAction: FloatingActionButton.extended(
        heroTag: 'trainer-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showTrainerSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('TRAINER', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: gym.trainers.isEmpty
          ? EmptyState(icon: Icons.sports_rounded, title: 'No trainers yet', subtitle: 'Add your coaches to assign members and classes.', actionLabel: 'ADD TRAINER', onAction: () => _showTrainerSheet(context))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
              children: [
                for (var i = 0; i < gym.trainers.length; i++) _TrainerCard(trainer: gym.trainers[i]).entrance(context, index: i),
              ],
            ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  final Trainer trainer;

  const _TrainerCard({required this.trainer});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final clients = gym.clientsOf(trainer.id);
    final classes = gym.classes.where((c) => c.trainerId == trainer.id).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => _showTrainerSheet(context, trainer: trainer),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.redGradient),
                alignment: Alignment.center,
                child: Text(initials(trainer.name), style: AppText.headline.copyWith(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(trainer.name, style: AppText.title),
                  Text(trainer.speciality, style: AppText.small.copyWith(color: AppColors.muted)),
                ]),
              ),
              IconButton(tooltip: 'Call', icon: const Icon(Icons.call_rounded), onPressed: () => callNumber(context, trainer.phone)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              StatusPill('${clients.length} clients', color: AppColors.categorical[0], icon: Icons.groups_rounded),
              const SizedBox(width: 8),
              StatusPill('$classes classes', color: AppColors.categorical[2], icon: Icons.event_rounded),
              const Spacer(),
              if (trainer.monthlySalary > 0 && gym.ownerUnlocked) Text('${formatMoney(trainer.monthlySalary)}/mo', style: AppText.small.copyWith(color: AppColors.muted)),
            ]),
            if (clients.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final m in clients.take(12))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => openPage(context, MemberProfileScreen(memberId: m.id)),
                        child: Tooltip(message: m.name, child: MemberAvatar(member: m, size: 42, heroTag: '-trainer')),
                      ),
                    ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showTrainerSheet(BuildContext context, {Trainer? trainer}) => showAppSheet<void>(context, builder: (_) => _TrainerSheet(trainer: trainer));

class _TrainerSheet extends StatefulWidget {
  final Trainer? trainer;

  const _TrainerSheet({this.trainer});

  @override
  State<_TrainerSheet> createState() => _TrainerSheetState();
}

class _TrainerSheetState extends State<_TrainerSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.trainer?.name ?? '');
  late final _speciality = TextEditingController(text: widget.trainer?.speciality ?? '');
  late final _phone = TextEditingController(text: widget.trainer?.phone ?? '');
  late final _salary = TextEditingController(text: (widget.trainer?.monthlySalary ?? 0) > 0 ? widget.trainer!.monthlySalary.toStringAsFixed(0) : '');

  @override
  void dispose() {
    for (final c in [_name, _speciality, _phone, _salary]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(widget.trainer == null ? 'New trainer' : 'Edit trainer'),
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_rounded)), validator: (v) => requiredText(v, 'Enter a name')),
            const SizedBox(height: 12),
            TextFormField(controller: _speciality, decoration: const InputDecoration(labelText: 'Speciality', hintText: 'Boxing, strength, Zumba...', prefixIcon: Icon(Icons.sports_mma_rounded))),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.call_rounded))),
            if (gym.ownerUnlocked) ...[
              const SizedBox(height: 12),
              AmountField(controller: _salary, label: 'Monthly salary (optional)'),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final base = widget.trainer ?? Trainer(id: gym.newTrainerId(), name: '', speciality: '', phone: '');
                await gym.saveTrainer(base.copyWith(
                  name: _name.text.trim(),
                  speciality: _speciality.text.trim(),
                  phone: _phone.text.trim(),
                  monthlySalary: gym.ownerUnlocked ? (parseAmount(_salary.text) ?? 0) : null,
                ));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('SAVE'),
            ),
            if (widget.trainer != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  if (!await ensureOwner(context) || !context.mounted) return;
                  if (await confirmAction(context, title: 'Remove ${widget.trainer!.name}?', message: 'Their members and classes stay, just without a trainer.') && context.mounted) {
                    await gym.deleteTrainer(widget.trainer!.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Remove trainer'),
              ),
          ],
        ),
      ),
    );
  }
}
