import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';

/// Adds a walk-in or phone enquiry, or edits one.
Future<void> showEnquirySheet(BuildContext context, {Enquiry? enquiry}) => showAppSheet<void>(context, builder: (_) => _EnquirySheet(enquiry: enquiry));

class _EnquirySheet extends StatefulWidget {
  final Enquiry? enquiry;

  const _EnquirySheet({this.enquiry});

  @override
  State<_EnquirySheet> createState() => _EnquirySheetState();
}

class _EnquirySheetState extends State<_EnquirySheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.enquiry?.name ?? '');
  late final _phone = TextEditingController(text: widget.enquiry?.phone ?? '');
  late final _notes = TextEditingController(text: widget.enquiry?.notes ?? '');
  late Gender _gender = widget.enquiry?.gender ?? Gender.male;
  late String? _planId = widget.enquiry?.planId;
  late LeadSource _source = widget.enquiry?.source ?? LeadSource.walkIn;
  late EnquiryStatus _status = widget.enquiry?.status ?? EnquiryStatus.open;
  late DateTime? _followUp = widget.enquiry?.nextFollowUp ?? context.read<GymProvider>().today.add(const Duration(days: 1));

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final gym = context.read<GymProvider>();
    final base = widget.enquiry ?? Enquiry(id: gym.newEnquiryId(), name: '', phone: '', createdAt: gym.now);
    await gym.saveEnquiry(base.copyWith(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      gender: _gender,
      planId: _planId,
      clearPlan: _planId == null,
      source: _source,
      status: _status,
      nextFollowUp: _followUp,
      clearFollowUp: _followUp == null || !_status.isOpen,
      notes: _notes.text.trim(),
    ));
    if (!mounted) return;
    Navigator.pop(context);
    showMessage(context, widget.enquiry == null ? 'Enquiry saved. Follow-up ${_followUp == null ? 'not set' : relativeDay(_followUp!, gym.today).toLowerCase()}.' : 'Enquiry updated.');
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final today = gym.today;
    final quick = [('Tomorrow', 1), ('In 3 days', 3), ('Next week', 7)];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(widget.enquiry == null ? 'New enquiry' : 'Edit enquiry', subtitle: widget.enquiry == null ? 'Someone asked about joining. Save them so nobody forgets to follow up.' : null),
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(AppIcons.person)), validator: (v) => requiredText(v, 'Enter a name')),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (WhatsApp)', prefixIcon: Icon(AppIcons.call)), validator: validatePhone),
            const FieldLabel('Gender'),
            ChoiceChips<Gender>(options: Gender.values, selected: _gender, labelOf: (g) => g.label, onSelected: (g) => setState(() => _gender = g)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _planId,
              decoration: const InputDecoration(labelText: 'Interested in', prefixIcon: Icon(AppIcons.membership)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Not sure yet')),
                for (final p in gym.activePlans) DropdownMenuItem(value: p.id, child: Text('${p.name} · ${formatMoney(p.price)}')),
              ],
              onChanged: (v) => setState(() => _planId = v),
            ),
            const FieldLabel('How they found us'),
            ChoiceChips<LeadSource>(options: LeadSource.values, selected: _source, labelOf: (s) => s.label, iconOf: (s) => s.icon, onSelected: (s) => setState(() => _source = s)),
            if (widget.enquiry != null) ...[
              const FieldLabel('Status'),
              ChoiceChips<EnquiryStatus>(options: EnquiryStatus.values.where((s) => s != EnquiryStatus.converted).toList(), selected: _status, labelOf: (s) => s.label, onSelected: (s) => setState(() => _status = s)),
            ],
            if (_status.isOpen) ...[
              const FieldLabel('Follow up'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (label, days) in quick)
                  ChoiceChip(
                    label: Text(label),
                    selected: _followUp != null && dateOnly(_followUp!) == today.add(Duration(days: days)),
                    onSelected: (_) => setState(() => _followUp = today.add(Duration(days: days))),
                  ),
                ActionChip(
                  avatar: const Icon(AppIcons.event, size: 16),
                  label: Text(_followUp == null ? 'Pick a date' : formatDayMonth(_followUp!)),
                  onPressed: () async {
                    final d = await pickDate(context, initial: _followUp ?? today, first: today, last: today.add(const Duration(days: 120)));
                    if (d != null) setState(() => _followUp = d);
                  },
                ),
              ]),
            ],
            const SizedBox(height: 14),
            TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes', hintText: 'Timing, budget, goals...', prefixIcon: Icon(AppIcons.notes))),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: Text(widget.enquiry == null ? 'Save enquiry' : 'Save changes')),
            if (widget.enquiry != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  final ok = await confirmAction(context, title: 'Delete enquiry?', message: 'Remove ${widget.enquiry!.name} from the enquiry list.');
                  if (ok && context.mounted) {
                    await gym.deleteEnquiry(widget.enquiry!.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Delete enquiry'),
              ),
          ],
        ),
      ),
    );
  }
}
