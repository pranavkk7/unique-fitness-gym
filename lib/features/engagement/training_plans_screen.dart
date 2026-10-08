import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import 'member_pdfs.dart';

/// Workout and diet plan templates. Trainers edit them here, assign them from a member's profile,
/// and share them as a branded PDF.
class TrainingPlansScreen extends StatefulWidget {
  const TrainingPlansScreen({super.key});

  @override
  State<TrainingPlansScreen> createState() => _TrainingPlansScreenState();
}

class _TrainingPlansScreenState extends State<TrainingPlansScreen> {
  TrainingPlanKind _kind = TrainingPlanKind.workout;

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final plans = gym.trainingPlans.where((p) => p.kind == _kind).toList();
    int usedBy(TrainingPlan p) => gym.members.where((m) => m.workoutPlanId == p.id || m.dietPlanId == p.id).length;
    return SubPage(
      title: 'Workout & diet',
      subtitle: '${gym.trainingPlans.length} plan templates',
      floatingAction: FloatingActionButton.extended(
        heroTag: 'plan-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => openPage(context, TrainingPlanEditor(kind: _kind)),
        icon: const Icon(AppIcons.add),
        label: const Text('New plan', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          SegmentedButton<TrainingPlanKind>(
            segments: [for (final k in TrainingPlanKind.values) ButtonSegment(value: k, icon: Icon(k.icon), label: Text(k.label))],
            selected: {_kind},
            onSelectionChanged: (v) => setState(() => _kind = v.first),
          ),
          const SizedBox(height: 14),
          if (plans.isEmpty) const AppCard(child: Text('No plans of this kind yet.', style: AppText.bodyMuted)),
          for (var i = 0; i < plans.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => openPage(context, TrainingPlanEditor(kind: plans[i].kind, plan: plans[i])),
                child: Row(children: [
                  IconBadge(plans[i].kind.icon, color: plans[i].kind == TrainingPlanKind.workout ? AppColors.primary : AppColors.categorical[2]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(plans[i].name, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                      Text([if (plans[i].goal.isNotEmpty) plans[i].goal, '${plans[i].sections.length} sections', '${usedBy(plans[i])} members'].join(' · '), style: AppText.small.copyWith(color: AppColors.muted)),
                    ]),
                  ),
                  IconButton(tooltip: 'Share PDF', icon: const Icon(AppIcons.pdf, color: AppColors.muted), onPressed: () => sharePlanPdf(context, plans[i])),
                ]),
              ),
            ).entrance(context, index: i),
        ],
      ),
    );
  }
}

/// Edits a plan as titled sections (a day of training, or a meal).
class TrainingPlanEditor extends StatefulWidget {
  final TrainingPlanKind kind;
  final TrainingPlan? plan;

  const TrainingPlanEditor({super.key, required this.kind, this.plan});

  @override
  State<TrainingPlanEditor> createState() => _TrainingPlanEditorState();
}

class _TrainingPlanEditorState extends State<TrainingPlanEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.plan?.name ?? '');
  late final _goal = TextEditingController(text: widget.plan?.goal ?? '');
  late final _notes = TextEditingController(text: widget.plan?.notes ?? '');
  late final List<(TextEditingController, TextEditingController)> _sections = [
    for (final s in widget.plan?.sections ?? const <PlanSection>[]) (TextEditingController(text: s.title), TextEditingController(text: s.body)),
    if (widget.plan == null) (TextEditingController(), TextEditingController()),
  ];

  @override
  void dispose() {
    for (final c in [_name, _goal, _notes, for (final s in _sections) ...[s.$1, s.$2]]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final gym = context.read<GymProvider>();
    await gym.saveTrainingPlan(TrainingPlan(
      id: widget.plan?.id ?? gym.newTrainingPlanId(),
      kind: widget.kind,
      name: _name.text.trim(),
      goal: _goal.text.trim(),
      notes: _notes.text.trim(),
      sections: [
        for (final s in _sections)
          if (s.$1.text.trim().isNotEmpty || s.$2.text.trim().isNotEmpty) PlanSection(s.$1.text.trim(), s.$2.text.trim()),
      ],
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final diet = widget.kind == TrainingPlanKind.diet;
    return SubPage(
      title: widget.plan == null ? 'New ${widget.kind.label.toLowerCase()}' : 'Edit plan',
      actions: [
        if (widget.plan != null)
          IconButton(
            tooltip: 'Delete plan',
            icon: const Icon(AppIcons.delete),
            onPressed: () async {
              if (await confirmAction(context, title: 'Delete plan?', message: 'Members using it will have it removed.') && context.mounted) {
                await context.read<GymProvider>().deleteTrainingPlan(widget.plan!.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
      ],
      bottom: Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 14), child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('Save plan')))),
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            TextFormField(controller: _name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Plan name'), validator: (v) => requiredText(v, 'Enter a name')),
            const SizedBox(height: 12),
            TextFormField(controller: _goal, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: 'Goal', hintText: diet ? 'Weight loss · about 1,600 kcal' : 'Muscle gain · 4 days a week')),
            const FieldLabel('Sections'),
            for (var i = 0; i < _sections.length; i++)
              AnimatedSize(
                duration: Motion.medium,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: TextField(controller: _sections[i].$1, decoration: InputDecoration(hintText: diet ? 'Breakfast' : 'Monday · Chest', border: InputBorder.none, filled: false), style: AppText.title)),
                        IconButton(tooltip: 'Remove section', icon: const Icon(AppIcons.close, size: 18, color: AppColors.muted), onPressed: () => setState(() => _sections.removeAt(i))),
                      ]),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextField(controller: _sections[i].$2, minLines: 3, maxLines: null, decoration: InputDecoration(hintText: diet ? '2 idli, sambar, black coffee' : 'Bench press 4 × 8\nIncline press 3 × 10', helperText: 'One item per line')),
                      ),
                    ]),
                  ),
                ),
              ),
            OutlinedButton.icon(onPressed: () => setState(() => _sections.add((TextEditingController(), TextEditingController()))), icon: const Icon(AppIcons.add), label: const Text('Add section')),
            const SizedBox(height: 14),
            TextFormField(controller: _notes, maxLines: null, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          ],
        ),
      ),
    );
  }
}

/// Member profile section: the assigned workout and diet plans, each shareable as a PDF.
class TrainingPlansSection extends StatelessWidget {
  final Member member;

  const TrainingPlansSection({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Workout & diet'),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (final kind in TrainingPlanKind.values)
            Builder(builder: (context) {
              final plan = gym.trainingPlanById(kind == TrainingPlanKind.workout ? member.workoutPlanId : member.dietPlanId);
              return ListTile(
                onTap: () => _assign(context, kind, plan),
                leading: IconBadge(kind.icon, color: kind == TrainingPlanKind.workout ? AppColors.primary : AppColors.categorical[2], size: 38),
                title: Text(plan?.name ?? 'No ${kind.label.toLowerCase()}'),
                subtitle: Text(plan == null ? 'Tap to assign one' : plan.goal),
                trailing: plan == null
                    ? const Icon(AppIcons.addCircleOutline, color: AppColors.muted)
                    : IconButton(tooltip: 'Share ${kind.label} PDF', icon: const Icon(AppIcons.share), onPressed: () => sharePlanPdf(context, plan, member: member)),
              );
            }),
        ]),
      ),
    ]);
  }

  Future<void> _assign(BuildContext context, TrainingPlanKind kind, TrainingPlan? current) async {
    final gym = context.read<GymProvider>();
    final options = gym.trainingPlans.where((p) => p.kind == kind).toList();
    await showAppSheet<void>(
      context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetHeader(kind.label, subtitle: member.name),
            if (options.isEmpty) const Text('No plans yet. Add one under More > Workout & diet.', style: AppText.bodyMuted),
            for (final p in options)
              ListTile(
                onTap: () async {
                  await gym.assignTrainingPlan(member.id, kind, p.id);
                  if (sheet.mounted) Navigator.pop(sheet);
                },
                leading: Icon(p.id == current?.id ? AppIcons.radioOn : AppIcons.radioOff, color: p.id == current?.id ? AppColors.primaryBright : AppColors.muted),
                title: Text(p.name),
                subtitle: p.goal.isEmpty ? null : Text(p.goal),
              ),
            if (current != null)
              TextButton(
                onPressed: () async {
                  await gym.assignTrainingPlan(member.id, kind, null);
                  if (sheet.mounted) Navigator.pop(sheet);
                },
                child: const Text('Remove plan', style: TextStyle(color: AppColors.danger)),
              ),
          ]),
        ),
      ),
    );
  }
}
