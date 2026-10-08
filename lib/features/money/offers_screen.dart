import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
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

/// Offer codes for festivals and campaigns, entered at admission or renewal, plus the referral
/// reward setting.
class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final offers = gym.offers.toList()..sort((a, b) => (_live(gym, b) ? 1 : 0).compareTo(_live(gym, a) ? 1 : 0));
    final referred = gym.members.where((m) => m.referredById != null).toList();
    final topReferrers = <String, int>{};
    for (final m in referred) {
      topReferrers[m.referredById!] = (topReferrers[m.referredById!] ?? 0) + 1;
    }
    final ranked = topReferrers.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SubPage(
      title: 'Offers & referrals',
      subtitle: '${offers.where((o) => _live(gym, o)).length} live codes · ${referred.length} referred members',
      floatingAction: FloatingActionButton.extended(
        heroTag: 'offer-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showOfferSheet(context),
        icon: const Icon(AppIcons.add),
        label: const Text('New code', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          if (offers.isEmpty) const AppCard(child: Text('No offer codes yet. Create one for a festival or an Instagram campaign.', style: AppText.bodyMuted)),
          for (var i = 0; i < offers.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: _OfferTicket(offer: offers[i], live: _live(gym, offers[i]))).entrance(context, index: i),
          const SectionHeader('Referral reward'),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconBadge(AppIcons.gift, color: AppColors.categorical[2]),
                const SizedBox(width: 12),
                Expanded(child: Text('When a member brings a friend, their membership gets free days added.', style: AppText.body.copyWith(fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 12),
              ChoiceChips<int>(
                options: const [0, 7, 15, 30],
                selected: gym.settings.referralRewardDays,
                labelOf: (d) => d == 0 ? 'Off' : '$d days',
                onSelected: (d) => gym.updateSettings(gym.settings.copyWith(referralRewardDays: d)),
              ),
            ]),
          ),
          if (ranked.isNotEmpty) ...[
            const SectionHeader('Top referrers'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final e in ranked.take(5))
                  ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.surfaceHigher, child: Text(initials(gym.memberById(e.key)?.name ?? '?'), style: AppText.small.copyWith(color: AppColors.text))),
                    title: Text(gym.memberById(e.key)?.name ?? 'Former member'),
                    subtitle: Text('Brought ${e.value} ${e.value == 1 ? 'friend' : 'friends'}'),
                    trailing: Text('+${e.value * gym.settings.referralRewardDays}d', style: AppText.number.copyWith(color: AppColors.success)),
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  static bool _live(GymProvider gym, Offer o) => o.active && (o.validUntil == null || !gym.today.isAfter(dateOnly(o.validUntil!))) && (o.maxUses == 0 || o.used < o.maxUses);
}

/// An offer drawn like a ticket stub.
class _OfferTicket extends StatelessWidget {
  final Offer offer;
  final bool live;

  const _OfferTicket({required this.offer, required this.live});

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final status = !o.active
        ? 'Paused'
        : o.maxUses > 0 && o.used >= o.maxUses
            ? 'Used up'
            : o.validUntil != null && !live
                ? 'Ended ${formatDayMonth(o.validUntil!)}'
                : o.validUntil == null
                    ? 'No end date'
                    : 'Till ${formatDayMonth(o.validUntil!)}';
    return Opacity(
      opacity: live ? 1 : 0.55,
      child: AppCard(
        onTap: () => _showOfferSheet(context, offer: o),
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 104,
              decoration: BoxDecoration(gradient: live ? AppColors.redGradient : null, color: live ? null : AppColors.surfaceHigher, borderRadius: const BorderRadius.horizontal(left: Radius.circular(21))),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              child: FittedBox(child: Text(o.label, style: AppText.headline.copyWith(color: Colors.white, fontSize: 22), textAlign: TextAlign.center)),
            ),
            CustomPaint(size: const Size(2, double.infinity), painter: _DashPainter()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(o.code, style: AppText.title.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('$status · used ${o.used}${o.maxUses > 0 ? ' of ${o.maxUses}' : ''}', style: AppText.small.copyWith(color: AppColors.muted)),
                  if (o.maxUses > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: (o.used / o.maxUses).clamp(0, 1).toDouble(), minHeight: 5, backgroundColor: AppColors.surfaceHigher, color: AppColors.primaryBright),
                    ),
                  ],
                ]),
              ),
            ),
            IconButton(
              tooltip: 'Copy code',
              icon: const Icon(AppIcons.copy, size: 18, color: AppColors.muted),
              onPressed: () => Clipboard.setData(ClipboardData(text: o.code)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 2;
    for (var y = 4.0; y < size.height - 4; y += 9) {
      canvas.drawLine(Offset(1, y), Offset(1, y + 4), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}

Future<void> _showOfferSheet(BuildContext context, {Offer? offer}) => showAppSheet<void>(context, builder: (_) => _OfferSheet(offer: offer));

class _OfferSheet extends StatefulWidget {
  final Offer? offer;

  const _OfferSheet({this.offer});

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.offer?.code ?? '');
  late final _value = TextEditingController(text: widget.offer == null ? '' : widget.offer!.value.toStringAsFixed(0));
  late final _maxUses = TextEditingController(text: (widget.offer?.maxUses ?? 0) > 0 ? '${widget.offer!.maxUses}' : '');
  late bool _percent = widget.offer?.percent ?? true;
  late DateTime? _until = widget.offer?.validUntil;
  late bool _active = widget.offer?.active ?? true;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final gym = context.read<GymProvider>();
    final o = Offer(
      id: widget.offer?.id ?? gym.newOfferId(),
      code: _code.text.trim().toUpperCase(),
      percent: _percent,
      value: parseAmount(_value.text)!,
      validUntil: _until,
      maxUses: int.tryParse(_maxUses.text.trim()) ?? 0,
      used: widget.offer?.used ?? 0,
      active: _active,
    );
    try {
      await gym.saveOffer(o);
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
    }
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
            SheetHeader(widget.offer == null ? 'New offer code' : 'Edit offer', subtitle: 'Members say the code at the desk; it is applied as a discount.'),
            TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), LengthLimitingTextInputFormatter(14)],
              decoration: InputDecoration(labelText: 'Code', hintText: 'ONAM10', prefixIcon: const Icon(AppIcons.ticket), errorText: _error),
              validator: (v) => requiredText(v, 'Enter a code'),
            ),
            const FieldLabel('Discount'),
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: true, label: Text('Percent')), ButtonSegment(value: false, label: Text('Rupees off'))],
              selected: {_percent},
              onSelectionChanged: (v) => setState(() => _percent = v.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _percent ? 'Percent off' : 'Rupees off', suffixText: _percent ? '%' : null, prefixText: _percent ? null : '₹ '),
              validator: (v) {
                final n = parseAmount(v ?? '') ?? 0;
                if (n <= 0) return 'Enter the discount';
                if (_percent && n > 100) return 'At most 100%';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: PickerField(
                  label: 'Valid until',
                  value: _until == null ? null : formatDate(_until!),
                  icon: AppIcons.event,
                  onTap: () async {
                    final d = await pickDate(context, initial: _until ?? gym.today.add(const Duration(days: 30)), first: gym.today.subtract(const Duration(days: 365)), last: gym.today.add(const Duration(days: 730)));
                    if (d != null) setState(() => _until = d);
                  },
                  onClear: () => setState(() => _until = null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _maxUses, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max uses', hintText: 'No limit'))),
            ]),
            if (widget.offer != null) SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (v) => setState(() => _active = v), title: const Text('Code is active')),
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: const Text('Save code')),
            if (widget.offer != null)
              TextButton(
                onPressed: () async {
                  if (await confirmAction(context, title: 'Delete code?', message: '${widget.offer!.code} will stop working.') && context.mounted) {
                    await gym.deleteOffer(widget.offer!.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Delete code', style: TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
      ),
    );
  }
}

/// A code field for admission and renewal. Reports the matching offer and its discount on
/// [price], or null when the code is blank or invalid.
class OfferCodeField extends StatefulWidget {
  final double price;
  final void Function(Offer? offer, double discount) onChanged;

  const OfferCodeField({super.key, required this.price, required this.onChanged});

  @override
  State<OfferCodeField> createState() => _OfferCodeFieldState();
}

class _OfferCodeFieldState extends State<OfferCodeField> {
  final _code = TextEditingController();
  ({Offer? offer, double discount, String? error}) _result = (offer: null, discount: 0, error: null);

  @override
  void didUpdateWidget(OfferCodeField old) {
    super.didUpdateWidget(old);
    if (old.price != widget.price && _code.text.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final r = context.read<GymProvider>().checkOffer(_code.text, widget.price);
    setState(() => _result = r);
    widget.onChanged(r.offer, r.discount);
  }

  @override
  Widget build(BuildContext context) {
    final ok = _result.offer != null;
    return TextField(
      controller: _code,
      textCapitalization: TextCapitalization.characters,
      onChanged: (_) => _check(),
      decoration: InputDecoration(
        labelText: 'Offer code',
        prefixIcon: const Icon(AppIcons.ticket),
        errorText: _result.error,
        helperText: ok ? '${_result.offer!.label} · saves ${formatMoney(_result.discount)}' : null,
        helperStyle: AppText.small.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
        suffixIcon: AnimatedSwitcher(duration: Motion.fast, child: ok ? const Icon(AppIcons.checkCircle, color: AppColors.success, key: ValueKey('ok')) : const SizedBox.shrink()),
      ),
    );
  }
}
