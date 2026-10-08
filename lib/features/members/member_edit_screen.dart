import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';

/// Edits a member's personal details. Plan and dates change through Renew and Freeze, so the
/// membership history stays correct.
class MemberEditScreen extends StatefulWidget {
  final String memberId;

  const MemberEditScreen({super.key, required this.memberId});

  @override
  State<MemberEditScreen> createState() => _MemberEditScreenState();
}

class _MemberEditScreenState extends State<MemberEditScreen> {
  final _form = GlobalKey<FormState>();
  late Member _m;
  late final TextEditingController _name, _phone, _email, _address, _goal, _height, _weight, _medical, _eName, _ePhone, _notes;
  late Gender _gender;
  late LeadSource _source;
  DateTime? _dob;
  String? _trainerId;

  @override
  void initState() {
    super.initState();
    _m = context.read<GymProvider>().memberById(widget.memberId)!;
    _name = TextEditingController(text: _m.name);
    _phone = TextEditingController(text: _m.phone);
    _email = TextEditingController(text: _m.email);
    _address = TextEditingController(text: _m.address);
    _goal = TextEditingController(text: _m.goal);
    _height = TextEditingController(text: _m.heightCm?.round().toString() ?? '');
    _weight = TextEditingController(text: _m.weightKg?.toStringAsFixed(1) ?? '');
    _medical = TextEditingController(text: _m.medicalNotes);
    _eName = TextEditingController(text: _m.emergencyName);
    _ePhone = TextEditingController(text: _m.emergencyPhone);
    _notes = TextEditingController(text: _m.notes);
    _gender = _m.gender;
    _source = _m.source;
    _dob = _m.dateOfBirth;
    _trainerId = _m.trainerId;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _goal, _height, _weight, _medical, _eName, _ePhone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final h = parseAmount(_height.text), w = parseAmount(_weight.text);
    await context.read<GymProvider>().updateMember(_m.copyWith(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          address: _address.text.trim(),
          goal: _goal.text.trim(),
          gender: _gender,
          source: _source,
          dateOfBirth: _dob,
          clearDateOfBirth: _dob == null,
          trainerId: _trainerId,
          clearTrainer: _trainerId == null,
          heightCm: h,
          clearHeight: h == null,
          weightKg: w,
          clearWeight: w == null,
          medicalNotes: _medical.text.trim(),
          emergencyName: _eName.text.trim(),
          emergencyPhone: _ePhone.text.trim(),
          notes: _notes.text.trim(),
        ));
    if (!mounted) return;
    Navigator.pop(context);
    showMessage(context, 'Details saved.');
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    return SubPage(
      title: 'Edit details',
      subtitle: '${memberCode(_m.number)} · ${_m.name}',
      bottom: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('SAVE CHANGES')))),
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_rounded)), validator: (v) => requiredText(v, "Enter the member's name")),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (WhatsApp)', prefixIcon: Icon(Icons.call_rounded)), validator: validatePhone),
            const SizedBox(height: 12),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.mail_rounded))),
            const FieldLabel('Gender'),
            ChoiceChips<Gender>(options: Gender.values, selected: _gender, labelOf: (g) => g.label, onSelected: (g) => setState(() => _gender = g)),
            const SizedBox(height: 14),
            PickerField(
              label: 'Date of birth',
              value: _dob == null ? null : formatDate(_dob!),
              icon: Icons.cake_rounded,
              onClear: () => setState(() => _dob = null),
              onTap: () async {
                final d = await pickDate(context, initial: _dob ?? DateTime(gym.today.year - 25), first: DateTime(1940), last: gym.today);
                if (d != null) setState(() => _dob = d);
              },
            ),
            const FieldLabel('Training'),
            TextFormField(controller: _goal, decoration: const InputDecoration(labelText: 'Goal', prefixIcon: Icon(Icons.flag_rounded))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _trainerId,
              decoration: const InputDecoration(labelText: 'Trainer', prefixIcon: Icon(Icons.sports_rounded)),
              items: [
                const DropdownMenuItem(value: null, child: Text('No trainer')),
                for (final t in gym.trainers) DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() => _trainerId = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg'))),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _medical, maxLines: 2, decoration: const InputDecoration(labelText: 'Health conditions or injuries', prefixIcon: Icon(Icons.medical_information_rounded))),
            const FieldLabel('Emergency contact'),
            Row(children: [
              Expanded(child: TextFormField(controller: _eName, decoration: const InputDecoration(labelText: 'Name'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _ePhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))),
            ]),
            const FieldLabel('Other'),
            TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.home_rounded))),
            const SizedBox(height: 12),
            DropdownButtonFormField<LeadSource>(
              isExpanded: true,
              initialValue: _source,
              decoration: const InputDecoration(labelText: 'How they heard about us', prefixIcon: Icon(Icons.campaign_rounded)),
              items: [for (final s in LeadSource.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (v) => setState(() => _source = v ?? _source),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes_rounded))),
          ],
        ),
      ),
    );
  }
}
