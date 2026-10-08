import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../members/plan_picker.dart';

/// Membership plans and prices. Plans members are on cannot be deleted, only retired.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final counts = {for (final (p, n) in gym.planMix) p.id: n};
    // Offered plans first, then by tier and length, like the gym's price list.
    final plans = [...gym.plans]
      ..sort((a, b) {
        final byActive = (b.active ? 1 : 0).compareTo(a.active ? 1 : 0);
        if (byActive != 0) return byActive;
        final byTier = a.tier.index.compareTo(b.tier.index);
        return byTier != 0 ? byTier : a.months.compareTo(b.months);
      });
    return SubPage(
      title: 'Plans & pricing',
      floatingAction: FloatingActionButton.extended(
        heroTag: 'plan-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showPlanSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('PLAN', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          for (var i = 0; i < plans.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Opacity(
                opacity: plans[i].active ? 1 : 0.55,
                child: AppCard(
                  onTap: () => _showPlanSheet(context, plan: plans[i]),
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                            child: plans[i].tier == PlanTier.other
                                ? Text(plans[i].name, style: AppText.headline.copyWith(fontSize: 22))
                                : TierText(plans[i].name, tier: plans[i].tier, style: AppText.headline.copyWith(fontSize: 22)),
                          ),
                          if (plans[i].popular) ...[const SizedBox(width: 8), const StatusPill('Popular', color: AppColors.ember)],
                          if (!plans[i].active) ...[const SizedBox(width: 8), const StatusPill('Retired', color: AppColors.muted)],
                        ]),
                        const SizedBox(height: 2),
                        Text('${plans[i].durationLabel} · ${counts[plans[i].id] ?? 0} running members', style: AppText.small.copyWith(color: AppColors.muted)),
                        if (plans[i].perks.isNotEmpty) ...[const SizedBox(height: 6), Text(plans[i].perks, style: AppText.small)],
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(formatMoney(plans[i].price), style: AppText.headline.copyWith(fontSize: 22)),
                      if (plans[i].months > 1) Text('${formatMoney(plans[i].perMonth.round())}/mo', style: AppText.small.copyWith(color: AppColors.muted)),
                    ]),
                  ]),
                ),
              ),
            ).entrance(context, index: i),
          const SizedBox(height: 6),
          Text('Prices here are used for new admissions and renewals. Changing a price does not change what members already paid.', style: AppText.small.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

Future<void> _showPlanSheet(BuildContext context, {Plan? plan}) => showAppSheet<void>(context, builder: (_) => _PlanSheet(plan: plan));

class _PlanSheet extends StatefulWidget {
  final Plan? plan;

  const _PlanSheet({this.plan});

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.plan?.name ?? '');
  late final _price = TextEditingController(text: widget.plan?.price.toStringAsFixed(0) ?? '');
  late final _perks = TextEditingController(text: widget.plan?.perks ?? '');
  late int _months = widget.plan?.months ?? 1;
  late bool _popular = widget.plan?.popular ?? false;
  late bool _active = widget.plan?.active ?? true;
  late PlanTier _tier = widget.plan?.tier ?? PlanTier.silver;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _perks.dispose();
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
            SheetHeader(widget.plan == null ? 'New plan' : 'Edit plan'),
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Plan name', prefixIcon: Icon(Icons.card_membership_rounded)), validator: (v) => requiredText(v, 'Enter a name')),
            const SizedBox(height: 12),
            AmountField(controller: _price, label: 'Price', validator: (v) => (parseAmount(v ?? '') ?? 0) <= 0 ? 'Enter the price' : null),
            const FieldLabel('Tier'),
            ChoiceChips<PlanTier>(options: PlanTier.values, selected: _tier, labelOf: (t) => t.label, onSelected: (t) => setState(() => _tier = t)),
            const FieldLabel('Duration'),
            ChoiceChips<int>(options: const [1, 2, 3, 4, 6, 12], selected: _months, labelOf: (m) => m == 1 ? '1 month' : '$m months', onSelected: (m) => setState(() => _months = m)),
            const SizedBox(height: 14),
            TextFormField(controller: _perks, decoration: const InputDecoration(labelText: 'What is included', prefixIcon: Icon(Icons.auto_awesome_rounded))),
            const SizedBox(height: 6),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _popular, onChanged: (v) => setState(() => _popular = v), title: const Text('Mark as popular'), subtitle: const Text('Pre-selected for new admissions')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (v) => setState(() => _active = v), title: const Text('Offered at the desk'), subtitle: const Text('Turn off to retire a plan but keep its history')),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final base = widget.plan ?? Plan(id: gym.newPlanId(), name: '', months: 1, price: 0);
                await gym.savePlan(base.copyWith(name: _name.text.trim(), price: parseAmount(_price.text), months: _months, perks: _perks.text.trim(), popular: _popular, active: _active, tier: _tier));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('SAVE PLAN'),
            ),
            if (widget.plan != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  if (gym.planInUse(widget.plan!.id)) {
                    showMessage(context, 'Members are on this plan. Turn off "Offered at the desk" to retire it instead.');
                    return;
                  }
                  if (await confirmAction(context, title: 'Delete ${widget.plan!.name}?', message: 'This plan will be removed.') && context.mounted) {
                    await gym.deletePlan(widget.plan!.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Delete plan'),
              ),
          ],
        ),
      ),
    );
  }
}

