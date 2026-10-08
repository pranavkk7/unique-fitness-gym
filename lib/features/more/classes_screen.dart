import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import 'class_roster_screen.dart';

/// The weekly timetable. Pick a day; today is selected first and the running class is marked live.
class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late int _day = context.read<GymProvider>().today.weekday;
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final list = gym.classesOn(_day);
    final isToday = _day == gym.today.weekday;
    final nowMin = gym.now.hour * 60 + gym.now.minute;
    return SubPage(
      title: 'Classes',
      subtitle: 'Weekly timetable · ${gym.classes.length} classes',
      floatingAction: FloatingActionButton.extended(
        heroTag: 'class-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showClassSheet(context, day: _day),
        icon: const Icon(Icons.add_rounded),
        label: const Text('CLASS', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
            child: Row(children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Pressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _day = d);
                      },
                      haptic: false,
                      child: AnimatedContainer(
                        duration: Motion.medium,
                        curve: Motion.settle,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: _day == d ? AppColors.redGradient : null,
                          color: _day == d ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: d == gym.today.weekday && _day != d ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
                        ),
                        child: Column(children: [
                          Text(_days[d - 1].toUpperCase(), style: AppText.label.copyWith(fontSize: 10, color: _day == d ? Colors.white : AppColors.muted)),
                          const SizedBox(height: 2),
                          Text('${gym.classesOn(d).length}', style: AppText.headline.copyWith(fontSize: 18)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.medium,
              child: list.isEmpty
                  ? EmptyState(key: ValueKey('empty$_day'), icon: Icons.event_busy_rounded, title: 'No classes', subtitle: 'Nothing on the timetable for this day.')
                  : ListView(
                      key: ValueKey(_day),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                      children: [
                        for (var i = 0; i < list.length; i++)
                          _ClassRow(
                            gymClass: list[i],
                            live: isToday && nowMin >= list[i].startMinutes && nowMin < list[i].endMinutes,
                            done: isToday && nowMin >= list[i].endMinutes,
                          ).entrance(context, index: i),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  final GymClass gymClass;
  final bool live;
  final bool done;

  const _ClassRow({required this.gymClass, required this.live, required this.done});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final c = gymClass;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(minutesLabel(c.startMinutes).split(' ').first, style: AppText.headline.copyWith(fontSize: 20, color: done ? AppColors.muted : AppColors.text)),
                Text(minutesLabel(c.startMinutes).split(' ').last, style: AppText.label.copyWith(fontSize: 10)),
              ]),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Opacity(
                opacity: done ? 0.55 : 1,
                child: AppCard(
                  onTap: () => openPage(context, ClassRosterScreen(classId: c.id, onEdit: () => _showClassSheet(context, gymClass: c))),
                  borderColor: live ? c.type.color : null,
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(width: 4, height: 46, decoration: BoxDecoration(color: c.type.color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(c.title, style: AppText.title.copyWith(fontSize: 16))),
                          if (live) ...[const SizedBox(width: 8), StatusPill('Live now', color: c.type.color, icon: Icons.circle)],
                        ]),
                        const SizedBox(height: 3),
                        Text('${minutesLabel(c.startMinutes)} – ${minutesLabel(c.endMinutes)} · ${gym.trainerById(c.trainerId)?.name ?? 'No trainer'} ', style: AppText.small.copyWith(color: AppColors.muted)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(value: c.capacity == 0 ? 0 : c.memberIds.length / c.capacity, minHeight: 5, backgroundColor: AppColors.surfaceHigher, color: c.spotsLeft == 0 ? AppColors.warning : c.type.color),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${c.memberIds.length}/${c.capacity}', style: AppText.small.copyWith(fontWeight: FontWeight.w800)),
                        ]),
                        if (c.notes.isNotEmpty) Text(c.notes, style: AppText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    Icon(c.type.icon, color: c.type.color),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showClassSheet(BuildContext context, {GymClass? gymClass, int? day}) => showAppSheet<void>(context, builder: (_) => _ClassSheet(gymClass: gymClass, day: day));

class _ClassSheet extends StatefulWidget {
  final GymClass? gymClass;
  final int? day;

  const _ClassSheet({this.gymClass, this.day});

  @override
  State<_ClassSheet> createState() => _ClassSheetState();
}

class _ClassSheetState extends State<_ClassSheet> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.gymClass?.title ?? '');
  late final _notes = TextEditingController(text: widget.gymClass?.notes ?? '');
  late ClassType _type = widget.gymClass?.type ?? ClassType.strength;
  late final Set<int> _days = {...?widget.gymClass?.weekdays, if (widget.gymClass == null && widget.day != null) widget.day!};
  late int _start = widget.gymClass?.startMinutes ?? 18 * 60;
  late int _duration = widget.gymClass?.durationMin ?? 60;
  late int _capacity = widget.gymClass?.capacity ?? 20;
  late String? _trainerId = widget.gymClass?.trainerId;
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
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
            SheetHeader(widget.gymClass == null ? 'New class' : 'Edit class'),
            TextFormField(controller: _title, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Class name', prefixIcon: Icon(Icons.event_rounded)), validator: (v) => requiredText(v, 'Enter a name')),
            const FieldLabel('Type'),
            ChoiceChips<ClassType>(options: ClassType.values, selected: _type, labelOf: (t) => t.label, iconOf: (t) => t.icon, onSelected: (t) => setState(() => _type = t)),
            const FieldLabel('Days'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  selected: _days.contains(d),
                  label: Text(_dayNames[d - 1]),
                  onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
                ),
            ]),
            const SizedBox(height: 14),
            PickerField(
              label: 'Start time',
              value: minutesLabel(_start),
              icon: Icons.schedule_rounded,
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: _start ~/ 60, minute: _start % 60));
                if (t != null) setState(() => _start = t.hour * 60 + t.minute);
              },
            ),
            const FieldLabel('Length'),
            ChoiceChips<int>(options: const [30, 45, 60, 90, 120], selected: _duration, labelOf: (m) => m == 120 ? '2 hours' : '$m min', onSelected: (m) => setState(() => _duration = m)),
            const FieldLabel('Capacity'),
            Row(children: [
              IconButton.outlined(tooltip: 'Fewer spots', onPressed: _capacity > 1 ? () => setState(() => _capacity--) : null, icon: const Icon(Icons.remove_rounded)),
              Expanded(child: Text('$_capacity spots', textAlign: TextAlign.center, style: AppText.title)),
              IconButton.outlined(tooltip: 'More spots', onPressed: () => setState(() => _capacity++), icon: const Icon(Icons.add_rounded)),
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _trainerId,
              decoration: const InputDecoration(labelText: 'Trainer', prefixIcon: Icon(Icons.sports_rounded)),
              items: [const DropdownMenuItem(value: null, child: Text('No trainer')), for (final t in gym.trainers) DropdownMenuItem(value: t.id, child: Text(t.name))],
              onChanged: (v) => setState(() => _trainerId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_rounded))),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                if (_days.isEmpty) return;
                final base = widget.gymClass ?? GymClass(id: gym.newClassId(), title: '', type: _type, weekdays: const [], startMinutes: _start);
                await gym.saveClass(base.copyWith(
                  title: _title.text.trim(),
                  type: _type,
                  weekdays: (_days.toList()..sort()),
                  startMinutes: _start,
                  durationMin: _duration,
                  capacity: _capacity,
                  trainerId: _trainerId,
                  clearTrainer: _trainerId == null,
                  notes: _notes.text.trim(),
                ));
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(_days.isEmpty ? 'PICK AT LEAST ONE DAY' : 'SAVE CLASS'),
            ),
            if (widget.gymClass != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  if (await confirmAction(context, title: 'Delete class?', message: '${widget.gymClass!.title} will be removed from the timetable.') && context.mounted) {
                    await gym.deleteClass(widget.gymClass!.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Delete class'),
              ),
          ],
        ),
      ),
    );
  }
}
