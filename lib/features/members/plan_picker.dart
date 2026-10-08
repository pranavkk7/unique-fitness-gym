import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';

/// Plans grouped by tier. Pick Silver or Platinum on top (metallic cards with the tier's perks),
/// then a duration below. Each duration shows its price per month and the saving against paying
/// month by month. Switching tier keeps the chosen duration.
class PlanPicker extends StatelessWidget {
  final List<Plan> plans;
  final String? selectedId;
  final ValueChanged<Plan> onSelected;

  const PlanPicker({super.key, required this.plans, required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final selected = plans.where((p) => p.id == selectedId).firstOrNull;
    final tiers = [for (final t in PlanTier.values) if (plans.any((p) => p.tier == t)) t];
    final tier = selected?.tier ?? (tiers.isEmpty ? PlanTier.other : tiers.first);
    final inTier = plans.where((p) => p.tier == tier).toList()..sort((a, b) => a.months.compareTo(b.months));
    final monthly = inTier.where((p) => p.months == 1).firstOrNull;

    void pickTier(PlanTier t) {
      if (t == tier) return;
      HapticFeedback.selectionClick();
      final options = plans.where((p) => p.tier == t).toList()..sort((a, b) => a.months.compareTo(b.months));
      final same = options.where((p) => p.months == (selected?.months ?? 1)).firstOrNull;
      onSelected(same ?? options.first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tiers.length > 1)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < tiers.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _TierCard(tier: tiers[i], plans: plans, selected: tiers[i] == tier, onTap: () => pickTier(tiers[i]))),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          final perRow = box.maxWidth > 560 ? 6 : 3;
          final w = (box.maxWidth - 8 * (perRow - 1)) / perRow;
          return AnimatedSwitcher(
            duration: Motion.medium,
            child: Wrap(
              key: ValueKey(tier),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in inTier)
                  SizedBox(
                    width: w,
                    child: _DurationCard(
                      plan: p,
                      saving: monthly == null || p.months == 1 ? 0 : monthly.price * p.months - p.price,
                      selected: p.id == selectedId,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelected(p);
                      },
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Metallic look for a tier: silver like brushed steel, platinum in the gold of the gym's poster.
class TierStyle {
  final List<Color> metal;
  final Color accent;

  const TierStyle(this.metal, this.accent);

  static TierStyle of(PlanTier tier) => switch (tier) {
        PlanTier.silver => const TierStyle([Color(0xFFF4F5F8), Color(0xFF9EA3AE), Color(0xFFE3E5EA), Color(0xFF8A8F99)], Color(0xFFC9CDD5)),
        PlanTier.platinum => const TierStyle([Color(0xFFFFEDB0), Color(0xFFD29B32), Color(0xFFFFD873), Color(0xFFB07A1E)], Color(0xFFE9B44C)),
        PlanTier.other => const TierStyle([AppColors.primaryBright, AppColors.primary], AppColors.primary),
      };

  LinearGradient get gradient => LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: metal);
}

/// Text painted with the tier's metallic gradient, like the poster headings.
class TierText extends StatelessWidget {
  final String text;
  final PlanTier tier;
  final TextStyle style;

  const TierText(this.text, {super.key, required this.tier, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => TierStyle.of(tier).gradient.createShader(rect),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

class _TierCard extends StatelessWidget {
  final PlanTier tier;
  final List<Plan> plans;
  final bool selected;
  final VoidCallback onTap;

  const _TierCard({required this.tier, required this.plans, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = TierStyle.of(tier);
    final cheapest = plans.where((p) => p.tier == tier).map((p) => p.perMonth).fold<double>(double.infinity, (a, b) => b < a ? b : a);
    return Semantics(
      button: true,
      selected: selected,
      label: '${tier.label} membership',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: false,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.settle,
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            gradient: AppColors.surfaceGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? style.accent : AppColors.border, width: selected ? 1.8 : 1),
            boxShadow: selected ? [BoxShadow(color: style.accent.withValues(alpha: 0.28), blurRadius: 26, spreadRadius: -8, offset: const Offset(0, 10))] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: TierText(tier.label.toUpperCase(), tier: tier, style: AppText.display.copyWith(fontSize: 28))),
                AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: selected ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), color: style.accent, size: 22) : const SizedBox(key: ValueKey('off'), width: 22),
                ),
              ]),
              Text('MEMBERSHIP', style: AppText.label.copyWith(fontSize: 9.5, letterSpacing: 2.4, color: style.accent)),
              const SizedBox(height: 10),
              for (final perk in tier.perks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.check_rounded, size: 14, color: style.accent),
                    const SizedBox(width: 6),
                    Expanded(child: Text(perk, style: AppText.small.copyWith(fontSize: 12, color: AppColors.textSecondary))),
                  ]),
                ),
              const Spacer(),
              const SizedBox(height: 6),
              if (cheapest.isFinite) Text('From ${formatMoney(cheapest.round())}/mo', style: AppText.small.copyWith(color: AppColors.text, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationCard extends StatelessWidget {
  final Plan plan;
  final double saving;
  final bool selected;
  final VoidCallback onTap;

  const _DurationCard({required this.plan, required this.saving, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = TierStyle.of(plan.tier).accent;
    return Semantics(
      selected: selected,
      button: true,
      label: '${plan.name}, ${formatMoney(plan.price)}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: false,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.settle,
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.primaryDeep.withValues(alpha: 0.25)])
                : AppColors.surfaceGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.durationLabel.toUpperCase(), style: AppText.label.copyWith(fontSize: 10, color: selected ? AppColors.text : AppColors.muted), maxLines: 1),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(formatMoney(plan.price), style: AppText.headline.copyWith(fontSize: 20))),
              Text(plan.months > 1 ? '${formatMoney(plan.perMonth.round())}/mo' : 'per month', style: AppText.small.copyWith(fontSize: 11, color: AppColors.muted), maxLines: 1),
              const SizedBox(height: 6),
              SizedBox(
                height: 18,
                child: saving > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
                        child: FittedBox(child: Text('SAVE ${formatMoney(saving.round())}', style: AppText.label.copyWith(fontSize: 9, color: AppColors.success, letterSpacing: 0.6))),
                      )
                    : plan.popular
                        ? Text('POPULAR', style: AppText.label.copyWith(fontSize: 9, color: accent))
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cash, UPI, card or bank transfer.
class PayMethodPicker extends StatelessWidget {
  final PayMethod selected;
  final ValueChanged<PayMethod> onSelected;

  const PayMethodPicker({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in PayMethod.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: m == PayMethod.values.last ? 0 : 8),
              child: Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(m);
                },
                haptic: false,
                child: AnimatedContainer(
                  duration: Motion.fast,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected == m ? AppColors.primary.withValues(alpha: 0.18) : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected == m ? AppColors.primary : AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(m.icon, color: selected == m ? AppColors.primaryBright : AppColors.muted, size: 22),
                      const SizedBox(height: 4),
                      Text(m == PayMethod.bank ? 'Bank' : m.label, style: AppText.small.copyWith(color: selected == m ? AppColors.text : AppColors.textSecondary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A bill summary row: label left, amount right.
class BillRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  final bool negative;
  final Color? color;

  const BillRow(this.label, this.amount, {super.key, this.bold = false, this.negative = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = bold ? AppText.title.copyWith(fontFeatures: const [FontFeature.tabularFigures()]) : AppText.body.copyWith(color: AppColors.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style.copyWith(color: color))),
          Text('${negative ? '− ' : ''}${formatMoney(amount)}', style: style.copyWith(color: color)),
        ],
      ),
    );
  }
}
