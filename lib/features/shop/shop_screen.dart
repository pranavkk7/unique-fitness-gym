import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../members/plan_picker.dart';
import '../money/payment_sheet.dart';

/// The counter shop: supplements, drinks and merchandise with stock. Tap items to fill a cart,
/// then take the payment in one step.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final month = gym.thisMonth;
    final monthSales = gym.sales.where((s) => sameMonth(s.date, month)).toList();
    final revenue = monthSales.fold(0.0, (s, x) => s + x.total);
    final profit = monthSales.expand((s) => s.lines).fold(0.0, (s, l) => s + l.qty * (l.price - (gym.productById(l.productId)?.cost ?? 0)));
    final best = <String, double>{};
    for (final l in monthSales.expand((s) => s.lines)) {
      best[l.name] = (best[l.name] ?? 0) + l.total;
    }
    final ranked = best.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final products = gym.products.where((p) => p.active).toList()..sort((a, b) => a.category.index.compareTo(b.category.index));
    final recent = gym.sales.toList()..sort((a, b) => b.date.compareTo(a.date));

    return SubPage(
      title: 'Shop',
      subtitle: '${products.length} items · ${gym.lowStock.length} low on stock',
      actions: [IconButton(tooltip: 'Add item', icon: const Icon(AppIcons.addBox), onPressed: () => showProductSheet(context))],
      floatingAction: products.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'shop-fab',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => showSellSheet(context),
              icon: const Icon(AppIcons.bag),
              label: const Text('New sale', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
            ),
      child: products.isEmpty
          ? EmptyState(
              icon: AppIcons.store,
              title: 'No items yet',
              subtitle: 'Add the supplements, drinks and T-shirts sold at the counter.',
              actionLabel: 'Add item',
              onAction: () => showProductSheet(context),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
              children: [
                Row(children: [
                  Expanded(child: FigureCard('Sales · ${formatShortMonth(month)}', formatMoneyCompact(revenue), AppColors.primaryBright)),
                  const SizedBox(width: 10),
                  Expanded(child: FigureCard('Margin', formatMoneyCompact(profit), AppColors.success)),
                  const SizedBox(width: 10),
                  Expanded(child: FigureCard('Bills', '${monthSales.length}', AppColors.categorical[0])),
                ]).entrance(context),
                if (gym.lowStock.isNotEmpty) ...[
                  const SectionHeader('Running low'),
                  AppCard(
                    borderColor: AppColors.warning.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final p in gym.lowStock)
                        ListTile(
                          leading: IconBadge(AppIcons.stock, color: p.stock == 0 ? AppColors.danger : AppColors.warning, size: 38),
                          title: Text(p.name),
                          subtitle: Text(p.stock == 0 ? 'Out of stock' : 'Only ${p.stock} left'),
                          trailing: TextButton(onPressed: () => showRestockSheet(context, p), child: const Text('Restock')),
                        ),
                    ]),
                  ).entrance(context, index: 1),
                ],
                if (ranked.isNotEmpty) ...[
                  const SectionHeader('Best sellers this month'),
                  AppCard(child: RankedBars(items: [for (final e in ranked.take(4)) (e.key, e.value, formatMoney(e.value))], color: AppColors.categorical[2])),
                ],
                const SectionHeader('Stock'),
                for (var i = 0; i < products.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      radius: 20,
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      onTap: () => showProductSheet(context, product: products[i]),
                      child: Row(children: [
                        IconBadge(products[i].category.icon, color: AppColors.categorical[products[i].category.index % 4]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(products[i].name, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                            Text('${formatMoney(products[i].price)} · ${products[i].category.label}', style: AppText.small.copyWith(color: AppColors.muted)),
                          ]),
                        ),
                        StatusPill('${products[i].stock} in stock', color: products[i].lowStock ? AppColors.warning : AppColors.success),
                        IconButton(tooltip: 'Restock ${products[i].name}', icon: const Icon(AppIcons.addCircleOutline, color: AppColors.muted), onPressed: () => showRestockSheet(context, products[i])),
                      ]),
                    ),
                  ).entrance(context, index: i + 2),
                if (recent.isNotEmpty) ...[
                  const SectionHeader('Recent sales'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final s in recent.take(8))
                        ListTile(
                          onTap: () => showReceiptActions(context, s.receiptNo),
                          leading: IconBadge(s.method.icon, color: AppColors.success, size: 38),
                          title: Text(s.lines.map((l) => '${l.qty} × ${l.name}').join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${s.buyerName.isEmpty ? 'Walk-in' : s.buyerName} · ${relativeDay(s.date, gym.today)}, ${formatTime(s.date)}'),
                          trailing: Text(formatMoney(s.total), style: AppText.number),
                        ),
                    ]),
                  ),
                ],
              ],
            ),
    );
  }
}

/// The cart: tap items to add, pick the buyer (optional), take the payment.
Future<void> showSellSheet(BuildContext context, {Member? member}) async {
  final receipt = await showAppSheet<String>(context, builder: (_) => _SellSheet(member: member));
  if (receipt != null && context.mounted) await showReceiptActions(context, receipt, justPaid: true);
}

class _SellSheet extends StatefulWidget {
  final Member? member;

  const _SellSheet({this.member});

  @override
  State<_SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends State<_SellSheet> {
  final _cart = <String, int>{};
  late Member? _member = widget.member;
  late PayMethod _method = context.read<GymProvider>().lastPayMethod;
  bool _saving = false;

  double _total(GymProvider gym) => _cart.entries.fold(0.0, (s, e) => s + (gym.productById(e.key)?.price ?? 0) * e.value);

  void _change(Product p, int delta) {
    final next = (_cart[p.id] ?? 0) + delta;
    if (next > p.stock) {
      showMessage(context, 'Only ${p.stock} ${p.name} in stock.');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => next <= 0 ? _cart.remove(p.id) : _cart[p.id] = next);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final sale = await context.read<GymProvider>().sell(_cart, memberId: _member?.id, method: _method);
      if (mounted) Navigator.pop(context, sale.receiptNo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, e is StateError ? e.message : 'Could not save the sale.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final products = gym.products.where((p) => p.active).toList()..sort((a, b) => a.category.index.compareTo(b.category.index));
    final total = _total(gym);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader('New sale', subtitle: 'Tap an item to add it. Stock updates when you save.'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in products)
                _ProductChip(product: p, qty: _cart[p.id] ?? 0, onAdd: () => _change(p, 1), onRemove: () => _change(p, -1)),
            ],
          ),
          const FieldLabel('Buyer'),
          PickerField(
            label: 'Member (optional)',
            value: _member?.name,
            icon: AppIcons.person,
            onTap: () async {
              final m = await pickMember(context, title: 'Who is buying?');
              if (m != null) setState(() => _member = m);
            },
            onClear: () => setState(() => _member = null),
          ),
          const FieldLabel('Paid by'),
          PayMethodPicker(selected: _method, onSelected: (v) => setState(() => _method = v)),
          UpiQrPanel(show: _method == PayMethod.upi && total > 0, amount: total, note: 'Shop'),
          CashChange(show: _method == PayMethod.cash && total > 0, amount: total),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(children: [
              for (final e in _cart.entries) BillRow('${e.value} × ${gym.productById(e.key)!.name}', gym.productById(e.key)!.price * e.value),
              if (_cart.isNotEmpty) const Divider(height: 18),
              BillRow('Total', total, bold: true),
            ]),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving || _cart.isEmpty ? null : _save,
            icon: const Icon(AppIcons.check),
            label: Text(_cart.isEmpty ? 'Add an item' : 'Take ${formatMoney(total)}'),
          ),
        ],
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  final Product product;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductChip({required this.product, required this.qty, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final out = product.stock == 0;
    final picked = qty > 0;
    return Semantics(
      button: true,
      label: '${product.name}, ${formatMoney(product.price)}, ${product.stock} in stock${picked ? ', $qty in cart' : ''}',
      excludeSemantics: true,
      child: Pressable(
        onTap: out ? null : onAdd,
        onLongPress: picked ? onRemove : null,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: picked ? AppColors.primary.withValues(alpha: 0.16) : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: picked ? AppColors.primary : AppColors.border, width: picked ? 1.5 : 1),
          ),
          child: Opacity(
            opacity: out ? 0.4 : 1,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(product.category.icon, size: 18, color: AppColors.muted),
                const Spacer(),
                if (picked)
                  InkWell(
                    onTap: onRemove,
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text('$qty  −', style: AppText.small.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              Text(product.name, style: AppText.body.copyWith(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(out ? 'Out of stock' : '${formatMoney(product.price)} · ${product.stock} left', style: AppText.small.copyWith(color: AppColors.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Add or edit an item.
Future<void> showProductSheet(BuildContext context, {Product? product}) => showAppSheet<void>(context, builder: (_) => _ProductSheet(product: product));

class _ProductSheet extends StatefulWidget {
  final Product? product;

  const _ProductSheet({this.product});

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _price = TextEditingController(text: widget.product == null ? '' : widget.product!.price.toStringAsFixed(0));
  late final _cost = TextEditingController(text: (widget.product?.cost ?? 0) > 0 ? widget.product!.cost.toStringAsFixed(0) : '');
  late final _stock = TextEditingController(text: '${widget.product?.stock ?? 0}');
  late final _low = TextEditingController(text: '${widget.product?.lowStockAt ?? 3}');
  late ProductCategory _category = widget.product?.category ?? ProductCategory.supplement;

  @override
  void dispose() {
    for (final c in [_name, _price, _cost, _stock, _low]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final gym = context.read<GymProvider>();
    final p = Product(
      id: widget.product?.id ?? gym.newProductId(),
      name: _name.text.trim(),
      category: _category,
      price: parseAmount(_price.text)!,
      cost: parseAmount(_cost.text) ?? 0,
      stock: int.tryParse(_stock.text.trim()) ?? 0,
      lowStockAt: int.tryParse(_low.text.trim()) ?? 3,
    );
    await gym.saveProduct(p);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(editing ? 'Edit item' : 'New item'),
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => requiredText(v, 'Enter a name')),
            const FieldLabel('Category'),
            ChoiceChips<ProductCategory>(options: ProductCategory.values, selected: _category, labelOf: (c) => c.label, iconOf: (c) => c.icon, onSelected: (c) => setState(() => _category = c)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: AmountField(controller: _price, label: 'Selling price', validator: (v) => (parseAmount(v ?? '') ?? 0) <= 0 ? 'Enter a price' : null)),
              const SizedBox(width: 10),
              Expanded(child: AmountField(controller: _cost, label: 'Cost (optional)')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'In stock'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _low, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Warn at'))),
            ]),
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: Text(editing ? 'Save item' : 'Add item')),
            if (editing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await context.read<GymProvider>().saveProduct(widget.product!.copyWith(active: false));
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Stop selling this item', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Adds stock; with a unit cost the purchase is also saved as an expense.
Future<void> showRestockSheet(BuildContext context, Product product) => showAppSheet<void>(context, builder: (_) => _RestockSheet(product: product));

class _RestockSheet extends StatefulWidget {
  final Product product;

  const _RestockSheet({required this.product});

  @override
  State<_RestockSheet> createState() => _RestockSheetState();
}

class _RestockSheetState extends State<_RestockSheet> {
  int _qty = 6;
  late final _cost = TextEditingController(text: widget.product.cost > 0 ? widget.product.cost.toStringAsFixed(0) : '');

  @override
  void dispose() {
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cost = parseAmount(_cost.text) ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader('Restock', subtitle: '${widget.product.name} · ${widget.product.stock} in stock now'),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filledTonal(tooltip: 'Fewer', onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(AppIcons.remove)),
            SizedBox(width: 90, child: Text('$_qty', textAlign: TextAlign.center, style: AppText.stat)),
            IconButton.filledTonal(tooltip: 'More', onPressed: () => setState(() => _qty++), icon: const Icon(AppIcons.add)),
          ]),
          const SizedBox(height: 14),
          AmountField(controller: _cost, label: 'Cost per item (optional)', onChanged: (_) => setState(() {})),
          if (cost > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${formatMoney(cost * _qty)} will be added to expenses.', style: AppText.small.copyWith(color: AppColors.muted))),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              await context.read<GymProvider>().restock(widget.product.id, _qty, unitCost: cost);
              if (context.mounted) {
                Navigator.pop(context);
                showMessage(context, '${widget.product.name}: ${widget.product.stock + _qty} in stock.');
              }
            },
            child: Text('Add $_qty to stock'),
          ),
        ],
      ),
    );
  }
}
