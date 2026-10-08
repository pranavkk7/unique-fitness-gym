import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/pin_pad.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../providers/gym_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final GymProvider _gym = context.read<GymProvider>();
  late final _gymName = TextEditingController(text: _gym.settings.gymName);
  late final _branch = TextEditingController(text: _gym.settings.branchName);
  late final _address = TextEditingController(text: _gym.settings.address);
  late final _phone = TextEditingController(text: _gym.settings.phone);
  late final _altPhone = TextEditingController(text: _gym.settings.altPhone);
  late final _tagline = TextEditingController(text: _gym.settings.tagline);
  late final _owner = TextEditingController(text: _gym.settings.ownerName);
  late final _upi = TextEditingController(text: _gym.settings.upiId);
  late final _fee = TextEditingController(text: _gym.settings.admissionFee.toStringAsFixed(0));
  late final _target = TextEditingController(text: _gym.settings.monthlyTarget.toStringAsFixed(0));
  late final _ownerPhone = TextEditingController(text: _gym.settings.ownerPhone);
  late bool _daily = _gym.settings.dailyNotification;
  late double _notifyHour = _gym.settings.notifyHour.toDouble();
  late double _trialDays = _gym.settings.trialDays.toDouble();
  late double _alertDays = _gym.settings.expiryAlertDays.toDouble();
  late double _inactiveDays = _gym.settings.inactiveAfterDays.toDouble();

  @override
  void dispose() {
    for (final c in [_gymName, _branch, _address, _phone, _altPhone, _tagline, _owner, _upi, _fee, _target, _ownerPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await _gym.updateSettings(_gym.settings.copyWith(
      gymName: _gymName.text.trim(),
      branchName: _branch.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      altPhone: _altPhone.text.trim(),
      tagline: _tagline.text.trim(),
      ownerName: _owner.text.trim(),
      upiId: _upi.text.trim(),
      admissionFee: parseAmount(_fee.text) ?? 0,
      monthlyTarget: parseAmount(_target.text) ?? 0,
      expiryAlertDays: _alertDays.round(),
      inactiveAfterDays: _inactiveDays.round(),
      ownerPhone: _ownerPhone.text.trim(),
      dailyNotification: _daily,
      notifyHour: _notifyHour.round(),
      trialDays: _trialDays.round(),
    ));
    if (mounted) showMessage(context, 'Settings saved.');
  }

  Future<void> _backup() async {
    final json = await _gym.exportBackup();
    if (!mounted) return;
    await shareFile(context, name: 'ufg-backup-${isoDay(_gym.today)}.json', content: json, mimeType: 'application/json', subject: 'Unique Fitness Gym backup');
  }

  Future<void> _restore() async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open the file picker.');
      return;
    }
    if (files.isEmpty || !mounted) return;
    final ok = await confirmAction(context, title: 'Restore backup?', message: 'Everything in the app is replaced by the backup "${files.first.name}". This cannot be undone.', confirmLabel: 'Restore');
    if (!ok || !mounted) return;
    try {
      final raw = utf8.decode(await files.first.readAsBytes());
      final count = await _gym.restoreBackup(raw);
      if (mounted) showMessage(context, 'Backup restored: $count members.');
    } on FormatException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    return SubPage(
      title: 'Settings',
      bottom: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('SAVE SETTINGS')))),
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const SectionHeader('Gym', padding: EdgeInsets.fromLTRB(2, 10, 2, 12)),
            TextFormField(controller: _gymName, decoration: const InputDecoration(labelText: 'Gym name', prefixIcon: Icon(Icons.storefront_rounded)), validator: (v) => requiredText(v, 'Enter the gym name')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _branch, decoration: const InputDecoration(labelText: 'Branch'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _owner, decoration: const InputDecoration(labelText: 'Owner name'))),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address (on receipts)', prefixIcon: Icon(Icons.place_rounded))),
            const SizedBox(height: 12),
            TextFormField(controller: _tagline, decoration: const InputDecoration(labelText: 'Tagline (on receipts)', prefixIcon: Icon(Icons.auto_awesome_rounded))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Gym phone (in messages)', prefixIcon: Icon(Icons.call_rounded)))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _altPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Second phone'))),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _upi,
              decoration: const InputDecoration(labelText: 'UPI ID for scan-to-pay', hintText: 'e.g. uniquefitness@okaxis', prefixIcon: Icon(Icons.qr_code_2_rounded)),
              validator: (v) => (v == null || v.trim().isEmpty || RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(v.trim())) ? null : 'Check the UPI ID (name@bank)',
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _ownerPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Owner\'s WhatsApp (day-close report)', prefixIcon: Icon(Icons.lock_clock_rounded))),
            const SectionHeader('Money'),
            Row(children: [
              Expanded(child: AmountField(controller: _fee, label: 'Admission fee')),
              const SizedBox(width: 10),
              Expanded(child: AmountField(controller: _target, label: 'Monthly target')),
            ]),
            const SectionHeader('Reminders'),
            _SliderRow(label: 'Expiring soon', value: _alertDays, min: 3, max: 15, unit: 'days before the end', onChanged: (v) => setState(() => _alertDays = v)),
            _SliderRow(label: 'Missing workouts', value: _inactiveDays, min: 5, max: 30, unit: 'days without a visit', onChanged: (v) => setState(() => _inactiveDays = v)),
            _SliderRow(label: 'Free trial', value: _trialDays, min: 1, max: 7, unit: 'days', onChanged: (v) => setState(() => _trialDays = v)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _daily,
              onChanged: (v) => setState(() => _daily = v),
              title: Text('Morning summary notification', style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
              subtitle: const Text('Plans ending, dues, birthdays and follow-ups, on this phone. Off while demo data is loaded.'),
            ),
            if (_daily) _SliderRow(label: 'Summary time', value: _notifyHour, min: 5, max: 12, unit: 'o\'clock', onChanged: (v) => setState(() => _notifyHour = v)),
            const SectionHeader('Security'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                ListTile(
                  leading: const IconBadge(Icons.pin_rounded, color: AppColors.primaryBright, size: 38),
                  title: Text(gym.settings.hasPin ? 'Change owner PIN' : 'Set an owner PIN'),
                  subtitle: const Text('Staff can use the desk; revenue, expenses and settings need the PIN.'),
                  onTap: () async {
                    if (await showSetPinSheet(context) && context.mounted) showMessage(context, 'Owner PIN saved.');
                  },
                ),
                if (gym.settings.hasPin)
                  ListTile(
                    leading: const IconBadge(Icons.lock_open_rounded, color: AppColors.muted, size: 38),
                    title: const Text('Remove PIN'),
                    onTap: () async {
                      if (await confirmAction(context, title: 'Remove PIN?', message: 'Everyone using this phone will see income and settings.', confirmLabel: 'Remove')) {
                        await gym.clearPin();
                      }
                    },
                  ),
              ]),
            ),
            const SectionHeader('Data'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                ListTile(
                  leading: const IconBadge(Icons.cloud_upload_rounded, color: AppColors.success, size: 38),
                  title: const Text('Back up now'),
                  subtitle: const Text('Save everything, photos included, to Drive or WhatsApp'),
                  onTap: _backup,
                ),
                ListTile(
                  leading: IconBadge(Icons.settings_backup_restore_rounded, color: AppColors.categorical[0], size: 38),
                  title: const Text('Restore from backup'),
                  subtitle: const Text('Replace this phone\'s data with a backup file'),
                  onTap: _restore,
                ),
                ListTile(
                  leading: IconBadge(Icons.table_view_rounded, color: AppColors.categorical[2], size: 38),
                  title: const Text('Export members (CSV)'),
                  subtitle: const Text('Opens in Excel or Google Sheets'),
                  onTap: () => shareFile(context, name: 'ufg-members-${isoDay(gym.today)}.csv', content: gym.exportMembersCsv(), mimeType: 'text/csv'),
                ),
                ListTile(
                  leading: const IconBadge(Icons.auto_awesome_rounded, color: AppColors.ember, size: 38),
                  title: const Text('Load demo data'),
                  subtitle: const Text('Fictional members to try the app'),
                  onTap: () async {
                    if (await confirmAction(context, title: 'Load demo data?', message: 'Current members and history are replaced with fictional ones.', confirmLabel: 'Load demo')) {
                      await gym.loadDemoData();
                    }
                  },
                ),
                ListTile(
                  leading: const IconBadge(Icons.delete_forever_rounded, color: AppColors.danger, size: 38),
                  title: const Text('Erase all data'),
                  subtitle: const Text('Keeps gym details and PIN'),
                  onTap: () async {
                    if (await confirmAction(context, title: 'Erase everything?', message: 'All members, payments, check-ins and expenses are deleted. Take a backup first.', confirmLabel: 'Erase')) {
                      await gym.resetAll();
                    }
                  },
                ),
              ]),
            ),
            const SizedBox(height: 18),
            Text(
              'Member data stays on this phone. The app sends nothing anywhere by itself: WhatsApp, calls and sharing open the phone\'s own apps.',
              style: AppText.small.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;

  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: AppText.body.copyWith(fontWeight: FontWeight.w700))),
        Text('${value.round()} $unit', style: AppText.small.copyWith(color: AppColors.primaryBright)),
      ]),
      Slider(value: value, min: min, max: max, divisions: (max - min).round(), label: '${value.round()}', onChanged: onChanged),
    ]);
  }
}
