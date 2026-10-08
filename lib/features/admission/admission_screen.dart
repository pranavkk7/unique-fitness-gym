import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../core/utils/photo.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../money/offers_screen.dart';
import '../members/plan_picker.dart';
import '../money/payment_sheet.dart';
import 'admission_success_screen.dart';

/// New admission in four short steps: who, health and goals, plan, and payment. Each step checks
/// its own fields before moving on, and the bill updates live as the plan or discount changes.
class AdmissionScreen extends StatefulWidget {
  final String? enquiryId;

  const AdmissionScreen({super.key, this.enquiryId});

  @override
  State<AdmissionScreen> createState() => _AdmissionScreenState();
}

class _AdmissionScreenState extends State<AdmissionScreen> {
  static const _steps = ['Personal', 'Health & goals', 'Plan', 'Payment'];
  final _forms = List.generate(4, (_) => GlobalKey<FormState>());
  int _step = 0;
  bool _forward = true;
  bool _saving = false;

  // Personal
  Uint8List? _photo;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  Gender _gender = Gender.male;
  DateTime? _dob;
  // Health
  String _goal = 'General fitness';
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _medical = TextEditingController();
  final _eName = TextEditingController();
  final _ePhone = TextEditingController();
  // Plan
  String? _planId;
  DateTime? _start;
  String? _trainerId;
  LeadSource _source = LeadSource.walkIn;
  // Payment
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  bool _paidEdited = false;
  bool _chargeFee = true;
  late PayMethod _method = context.read<GymProvider>().lastPayMethod;
  Offer? _offer;
  double _offerDiscount = 0;
  Member? _referrer;

  static const _goals = ['Weight loss', 'Muscle gain', 'General fitness', 'Boxing', 'Stamina', 'Strength', 'Flexibility'];

  @override
  void initState() {
    super.initState();
    final gym = context.read<GymProvider>();
    _planId = (gym.activePlans.where((p) => p.popular).firstOrNull ?? gym.activePlans.firstOrNull)?.id;
    final e = gym.enquiryById(widget.enquiryId);
    if (e != null) {
      _name.text = e.name;
      _phone.text = e.phone;
      _gender = e.gender;
      _source = e.source;
      if (gym.planById(e.planId)?.active ?? false) _planId = e.planId;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _height, _weight, _medical, _eName, _ePhone, _discount, _paid]) {
      c.dispose();
    }
    super.dispose();
  }

  Plan? get _plan => context.read<GymProvider>().planById(_planId);
  double get _fee => _chargeFee ? context.read<GymProvider>().settings.admissionFee : 0;
  double get _manualDiscount => (parseAmount(_discount.text) ?? 0).clamp(0, _plan?.price ?? 0).toDouble();
  double get _discountValue => (_manualDiscount + _offerDiscount).clamp(0, _plan?.price ?? 0).toDouble();
  double get _bill => (_plan?.price ?? 0) - _discountValue + _fee;

  void _syncPaid() {
    if (!_paidEdited) _paid.text = _bill.toStringAsFixed(0);
  }

  void _go(int to) {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _forward = to > _step;
      _step = to;
      if (_step == 3) _syncPaid();
    });
  }

  void _next() {
    if (!(_forms[_step].currentState?.validate() ?? true)) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_step == 2 && _plan == null) return;
    if (_step < 3) {
      _go(_step + 1);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final gym = context.read<GymProvider>();
    final result = await gym.admit(
      name: _name.text,
      phone: _phone.text,
      gender: _gender,
      planId: _planId!,
      dateOfBirth: _dob,
      email: _email.text,
      address: _address.text,
      trainerId: _trainerId,
      startDate: _start,
      goal: _goal,
      heightCm: parseAmount(_height.text),
      weightKg: parseAmount(_weight.text),
      medicalNotes: _medical.text,
      emergencyName: _eName.text,
      emergencyPhone: _ePhone.text,
      source: _source,
      discount: _discountValue,
      chargeAdmissionFee: _chargeFee,
      amountPaid: parseAmount(_paid.text) ?? 0,
      method: _method,
      photo: _photo,
      enquiryId: widget.enquiryId,
      referredById: _referrer?.id,
      offerId: _offer?.id,
    );
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: Motion.slow,
      pageBuilder: (_, _, _) => AdmissionSuccessScreen(result: result),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 1.06, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.settle)), child: child)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step - 1);
      },
      child: Scaffold(
        body: GlowBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    _TopBar(step: _step, title: _steps[_step], onClose: () => Navigator.pop(context)),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Motion.medium,
                        switchInCurve: Motion.settle,
                        switchOutCurve: Motion.exit,
                        transitionBuilder: (child, animation) {
                          final incoming = child.key == ValueKey(_step);
                          final dx = (incoming == _forward) ? 0.12 : -0.12;
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(animation), child: child),
                          );
                        },
                        child: KeyedSubtree(key: ValueKey(_step), child: Form(key: _forms[_step], child: _buildStep())),
                      ),
                    ),
                    _BottomBar(
                      step: _step,
                      saving: _saving,
                      nextLabel: _step == 3 ? 'Confirm admission' : 'Continue',
                      onBack: _step == 0 ? null : () => _go(_step - 1),
                      onNext: _next,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) { 0 => _personal(), 1 => _health(), 2 => _planStep(), _ => _payment() };

  Widget _scroll(List<Widget> children) => ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: children);

  Widget _personal() {
    final gym = context.read<GymProvider>();
    return _scroll([
      Center(
        child: Pressable(
          onTap: () async {
            final bytes = await pickMemberPhoto(context, allowRemove: _photo != null);
            if (bytes != null) setState(() => _photo = bytes.isEmpty ? null : bytes);
          },
          child: Semantics(
            button: true,
            label: _photo == null ? 'Take member photo' : 'Change member photo',
            child: AnimatedContainer(
              duration: Motion.medium,
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceHigh,
                border: Border.all(color: _photo == null ? AppColors.borderStrong : AppColors.primary, width: 2.5),
                image: _photo == null ? null : DecorationImage(image: MemoryImage(_photo!), fit: BoxFit.cover),
                boxShadow: _photo == null ? null : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: -6)],
              ),
              child: _photo == null
                  ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(AppIcons.addPhoto, color: AppColors.primaryBright, size: 30),
                      SizedBox(height: 4),
                      Text('Photo', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.muted)),
                    ])
                  : null,
            ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      TextFormField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(AppIcons.person)),
        validator: (v) => requiredText(v, "Enter the member's name"),
      ).entrance(context, index: 1),
      const SizedBox(height: 12),
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: 'Phone (WhatsApp)', prefixIcon: Icon(AppIcons.call)),
        validator: (v) {
          final basic = validatePhone(v);
          if (basic != null) return basic;
          final clash = gym.members.where((m) => digitsOnly(m.phone).endsWith(digitsOnly(v!).substring(digitsOnly(v).length - 10))).firstOrNull;
          return clash == null ? null : 'Already registered: ${clash.name} (${memberCode(clash.number)})';
        },
      ).entrance(context, index: 2),
      const FieldLabel('Gender'),
      ChoiceChips<Gender>(options: Gender.values, selected: _gender, labelOf: (g) => g.label, onSelected: (g) => setState(() => _gender = g)),
      const SizedBox(height: 14),
      PickerField(
        label: 'Date of birth (for birthday wishes)',
        value: _dob == null ? null : formatDate(_dob!),
        icon: AppIcons.cake,
        onClear: () => setState(() => _dob = null),
        onTap: () async {
          final d = await pickDate(context, initial: _dob ?? DateTime(gym.today.year - 22), first: DateTime(1940), last: gym.today);
          if (d != null) setState(() => _dob = d);
        },
      ),
      const SizedBox(height: 12),
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(AppIcons.mail))),
      const SizedBox(height: 12),
      TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address (optional)', prefixIcon: Icon(AppIcons.home))),
    ]);
  }

  Widget _health() {
    final h = parseAmount(_height.text), w = parseAmount(_weight.text);
    final bmi = (h != null && w != null && h > 0) ? w / ((h / 100) * (h / 100)) : null;
    final (bmiLabel, bmiColor) = bmi == null
        ? ('', AppColors.muted)
        : bmi < 18.5
            ? ('Underweight', AppColors.warning)
            : bmi < 25
                ? ('Healthy', AppColors.success)
                : bmi < 30
                    ? ('Overweight', AppColors.warning)
                    : ('Obese', AppColors.danger);
    return _scroll([
      const FieldLabel('Main goal'),
      ChoiceChips<String>(options: _goals, selected: _goal, labelOf: (g) => g, onSelected: (g) => setState(() => _goal = g)),
      const FieldLabel('Body'),
      Row(children: [
        Expanded(child: TextFormField(controller: _height, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm', prefixIcon: Icon(AppIcons.height)))),
        const SizedBox(width: 10),
        Expanded(child: TextFormField(controller: _weight, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg', prefixIcon: Icon(AppIcons.scale)))),
      ]),
      AnimatedSize(
        duration: Motion.medium,
        curve: Motion.settle,
        child: bmi == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Text('BMI', style: AppText.label.copyWith(color: AppColors.text)),
                    const SizedBox(width: 10),
                    Text(bmi.toStringAsFixed(1), style: AppText.headline.copyWith(fontSize: 24)),
                    const Spacer(),
                    StatusPill(bmiLabel, color: bmiColor),
                  ]),
                ),
              ),
      ),
      const SizedBox(height: 12),
      TextFormField(controller: _medical, maxLines: 2, decoration: const InputDecoration(labelText: 'Health conditions or injuries', hintText: 'e.g. knee injury, asthma, BP', prefixIcon: Icon(AppIcons.medical))),
      const FieldLabel('Emergency contact'),
      Row(children: [
        Expanded(child: TextFormField(controller: _eName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name'))),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: _ePhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
            validator: (v) => (v == null || v.trim().isEmpty) ? null : validatePhone(v),
          ),
        ),
      ]),
    ]);
  }

  Widget _planStep() {
    final gym = context.watch<GymProvider>();
    final plan = _plan;
    final start = _start ?? gym.today;
    return _scroll([
      PlanPicker(plans: gym.activePlans, selectedId: _planId, onSelected: (p) => setState(() => _planId = p.id)),
      if (plan != null && plan.tier == PlanTier.other && plan.perks.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(children: [const Icon(AppIcons.sparkle, size: 16, color: AppColors.ember), const SizedBox(width: 8), Expanded(child: Text(plan.perks, style: AppText.small))]),
      ],
      const SizedBox(height: 16),
      PickerField(
        label: 'Starts on',
        value: '${formatDate(start)}${plan == null ? '' : '  ·  ends ${formatDate(addMonths(start, plan.months))}'}',
        icon: AppIcons.event,
        onTap: () async {
          final d = await pickDate(context, initial: start, first: gym.today.subtract(const Duration(days: 30)), last: gym.today.add(const Duration(days: 60)));
          if (d != null) setState(() => _start = d);
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String?>(
        isExpanded: true,
        initialValue: _trainerId,
        decoration: const InputDecoration(labelText: 'Personal trainer (optional)', prefixIcon: Icon(AppIcons.trainer)),
        items: [
          const DropdownMenuItem(value: null, child: Text('No trainer')),
          for (final t in gym.trainers) DropdownMenuItem(value: t.id, child: Text('${t.name} · ${t.speciality}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => _trainerId = v),
      ),
      const FieldLabel('How did they hear about us?'),
      ChoiceChips<LeadSource>(options: LeadSource.values, selected: _source, labelOf: (s) => s.label, iconOf: (s) => s.icon, onSelected: (s) => setState(() => _source = s)),
      const SizedBox(height: 14),
      PickerField(
        label: 'Referred by a member (optional)',
        value: _referrer?.name,
        icon: AppIcons.gift,
        onTap: () async {
          final m = await pickMember(context, title: 'Who referred them?');
          if (m == null) return;
          setState(() {
            _referrer = m;
            _source = LeadSource.referral;
          });
        },
        onClear: () => setState(() => _referrer = null),
      ),
      if (_referrer != null && gym.settings.referralRewardDays > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text('${_referrer!.firstName} gets ${gym.settings.referralRewardDays} free days when this admission is saved.', style: AppText.small.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
        ),
    ]);
  }

  Widget _payment() {
    final gym = context.watch<GymProvider>();
    final plan = _plan!;
    final paid = parseAmount(_paid.text) ?? 0;
    final due = (_bill - paid).clamp(0, double.infinity).toDouble();
    return _scroll([
      AppCard(
        gradient: AppColors.redGradient,
        glow: true,
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total to pay', style: AppText.label.copyWith(color: Colors.white70)),
              const SizedBox(height: 4),
              CountUp(value: _bill, format: formatMoney, duration: Motion.medium, style: AppText.display.copyWith(fontSize: 40, color: Colors.white)),
              Text('${_name.text.trim().isEmpty ? 'New member' : _name.text.trim()} · ${plan.name}', style: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: Colors.white70, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Icon(AppIcons.receipt, color: Colors.white54, size: 40),
        ]),
      ),
      const SizedBox(height: 14),
      AppCard(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(children: [
          BillRow(plan.name, plan.price),
          if (gym.settings.admissionFee > 0)
            Row(children: [
              Expanded(child: Text('Admission fee ${formatMoney(gym.settings.admissionFee)}', style: AppText.body.copyWith(color: AppColors.textSecondary))),
              Switch(value: _chargeFee, onChanged: (v) => setState(() { _chargeFee = v; _syncPaid(); })),
            ]),
          if (_manualDiscount > 0) BillRow('Discount', _manualDiscount, negative: true, color: AppColors.success),
          if (_offer != null && _offerDiscount > 0) BillRow('Offer ${_offer!.code}', _offerDiscount, negative: true, color: AppColors.success),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: _discount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Discount', prefixText: '₹ ', prefixIcon: Icon(AppIcons.tag)),
            onChanged: (_) => setState(_syncPaid),
            validator: (v) => (parseAmount(v ?? '') ?? 0) > plan.price ? 'More than the plan' : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: _paid,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Paid now', prefixText: '₹ ', prefixIcon: Icon(AppIcons.cash)),
            onChanged: (_) => setState(() => _paidEdited = true),
            validator: (v) => (parseAmount(v ?? '') ?? 0) < 0 ? 'Check the amount' : null,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      OfferCodeField(
        price: plan.price - _manualDiscount,
        onChanged: (offer, discount) => setState(() {
          _offer = offer;
          _offerDiscount = discount;
          _syncPaid();
        }),
      ),
      AnimatedSize(
        duration: Motion.medium,
        child: due > 0
            ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  const Icon(AppIcons.info, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${formatMoney(due)} will be saved as balance due, with a reminder.', style: AppText.small.copyWith(color: AppColors.warning))),
                ]),
              )
            : const SizedBox(width: double.infinity),
      ),
      const FieldLabel('Paid by'),
      PayMethodPicker(selected: _method, onSelected: (v) => setState(() => _method = v)),
      UpiQrPanel(show: _method == PayMethod.upi, amount: paid, note: 'Admission ${_name.text.trim()}'),
      CashChange(show: _method == PayMethod.cash, amount: paid),
    ]);
  }
}

class _TopBar extends StatelessWidget {
  final int step;
  final String title;
  final VoidCallback onClose;

  const _TopBar({required this.step, required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          IconButton(tooltip: 'Close', icon: const Icon(AppIcons.close), onPressed: onClose),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New admission', style: AppText.display.copyWith(fontSize: 26)),
                AnimatedSwitcher(
                  duration: Motion.fast,
                  child: Text('Step ${step + 1} of 4 · $title', key: ValueKey(step), style: AppText.small.copyWith(color: AppColors.primaryBright)),
                ),
              ],
            ),
          ),
          StepDots(count: 4, current: step),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int step;
  final bool saving;
  final String nextLabel;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  const _BottomBar({required this.step, required this.saving, required this.nextLabel, required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.settle,
            child: onBack == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: OutlinedButton(onPressed: onBack, style: OutlinedButton.styleFrom(minimumSize: const Size(96, 54)), child: const Text('Back')),
                  ),
          ),
          Expanded(
            child: FilledButton(
              onPressed: saving ? null : onNext,
              child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(nextLabel),
            ),
          ),
        ],
      ),
    );
  }
}
