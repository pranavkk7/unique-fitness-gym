import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/contact.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';

/// Records a body check: weight is required, the rest is optional.
Future<void> showMeasurementSheet(BuildContext context, Member member) => showAppSheet<void>(context, builder: (_) => _MeasurementSheet(member: member));

class _MeasurementSheet extends StatefulWidget {
  final Member member;

  const _MeasurementSheet({required this.member});

  @override
  State<_MeasurementSheet> createState() => _MeasurementSheetState();
}

class _MeasurementSheetState extends State<_MeasurementSheet> {
  final _form = GlobalKey<FormState>();
  late final _weight = TextEditingController(text: widget.member.weightKg?.toStringAsFixed(1) ?? '');
  final _fat = TextEditingController();
  final _waist = TextEditingController();
  final _chest = TextEditingController();
  final _arm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_weight, _fat, _waist, _chest, _arm]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, String suffix, {bool required = false}) => TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        validator: required ? (v) => ((parseAmount(v ?? '') ?? 0) <= 0 ? 'Enter the weight' : null) : null,
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader('Body check', subtitle: 'For ${widget.member.name}. Shows up on the progress chart.'),
            _field(_weight, 'Weight', 'kg', required: true),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: _field(_fat, 'Body fat', '%')), const SizedBox(width: 10), Expanded(child: _field(_waist, 'Waist', 'cm'))]),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: _field(_chest, 'Chest', 'cm')), const SizedBox(width: 10), Expanded(child: _field(_arm, 'Arm', 'cm'))]),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                await context.read<GymProvider>().addMeasurement(
                      widget.member.id,
                      weightKg: parseAmount(_weight.text)!,
                      bodyFatPct: parseAmount(_fat.text),
                      waistCm: parseAmount(_waist.text),
                      chestCm: parseAmount(_chest.text),
                      armCm: parseAmount(_arm.text),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  showMessage(context, 'Body check saved.');
                }
              },
              child: const Text('Save check'),
            ),
          ],
        ),
      ),
    );
  }
}
