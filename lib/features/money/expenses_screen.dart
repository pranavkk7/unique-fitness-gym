import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
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

/// Running costs month by month: rent, salaries, electricity, equipment.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late DateTime _month = context.read<GymProvider>().thisMonth;

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final list = gym.expenses.where((e) => sameMonth(e.date, _month)).toList()..sort((a, b) => b.date.compareTo(a.date));
    final total = list.fold(0.0, (s, e) => s + e.amount);
    final income = gym.incomeIn(_month);
    final isCurrent = sameMonth(_month, gym.today);
    return SubPage(
      title: 'Expenses',
      floatingAction: FloatingActionButton.extended(
        heroTag: 'expense-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => showExpenseSheet(context),
        icon: const Icon(AppIcons.add),
        label: const Text('Add expense', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          Row(children: [
            IconButton(tooltip: 'Previous month', icon: const Icon(AppIcons.chevronLeft), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
            Expanded(child: Text(formatMonthYear(_month), textAlign: TextAlign.center, style: AppText.headline.copyWith(fontSize: 20))),
            IconButton(tooltip: 'Next month', icon: const Icon(AppIcons.chevronRight), onPressed: isCurrent ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Figure('Spent', total, AppColors.seriesCompare)),
            const SizedBox(width: 10),
            Expanded(child: _Figure('Income', income, AppColors.primaryBright)),
            const SizedBox(width: 10),
            Expanded(child: _Figure('Profit', income - total, income - total >= 0 ? AppColors.success : AppColors.danger)),
          ]).entrance(context),
          const SectionHeader('Salaries this month'),
          _Salaries(month: _month),
          const SectionHeader('Entries'),
          if (list.isEmpty)
            const AppCard(child: Text('Nothing recorded for this month.', style: AppText.bodyMuted))
          else
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Dismissible(
                  key: ValueKey(list[i].id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(AppIcons.delete, color: AppColors.danger),
                  ),
                  confirmDismiss: (_) => confirmAction(context, title: 'Delete expense?', message: '${list[i].category.label}, ${formatMoney(list[i].amount)}'),
                  onDismissed: (_) => gym.deleteExpense(list[i].id),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                    radius: 20,
                    child: Row(children: [
                      IconBadge(list[i].category.icon, color: list[i].category.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(list[i].category.label, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                          Text('${formatDate(list[i].date)}${list[i].note.isEmpty ? '' : ' · ${list[i].note}'}', style: AppText.small.copyWith(color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      Text(formatMoney(list[i].amount), style: AppText.number),
                    ]),
                  ),
                ),
              ).entrance(context, index: i),
          if (list.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Swipe left to delete an entry.', style: AppText.small.copyWith(color: AppColors.muted), textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _Figure(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.label.copyWith(fontSize: 9.5)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: CountUp(value: value, format: (v) => '${v < 0 ? '−' : ''}${formatMoneyCompact(v.abs())}', style: AppText.headline.copyWith(fontSize: 20, color: color))),
        ]),
      );
}

class _Salaries extends StatelessWidget {
  final DateTime month;

  const _Salaries({required this.month});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final staff = gym.trainers.where((t) => t.monthlySalary > 0).toList();
    if (staff.isEmpty) return const AppCard(child: Text('Add trainer salaries under Trainers to pay them here in one tap.', style: AppText.bodyMuted));
    // Salaries are paid at the start of the next month for the month worked.
    final worked = DateTime(month.year, month.month - 1);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        for (final t in staff)
          ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.surfaceHigher, child: Text(initials(t.name), style: AppText.small.copyWith(color: AppColors.text))),
            title: Text(t.name),
            subtitle: Text('${formatMoney(t.monthlySalary)} for ${formatMonthYear(worked)}'),
            trailing: gym.salaryPaid(t.id, worked)
                ? const StatusPill('Paid', color: AppColors.success, icon: AppIcons.check)
                : TextButton(
                    onPressed: () async {
                      final ok = await gym.paySalary(t.id, worked);
                      if (ok && context.mounted) showMessage(context, 'Salary for ${t.name} recorded.');
                    },
                    child: const Text('Pay'),
                  ),
          ),
      ]),
    );
  }
}

/// Adds an expense.
Future<void> showExpenseSheet(BuildContext context) => showAppSheet<void>(context, builder: (_) => const _ExpenseSheet());

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet();

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.electricity;
  PayMethod _method = PayMethod.upi;
  late DateTime _date = context.read<GymProvider>().now;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
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
            const SheetHeader('Add expense'),
            AmountField(controller: _amount, label: 'Amount', autofocus: true, validator: (v) => (parseAmount(v ?? '') ?? 0) <= 0 ? 'Enter the amount' : null),
            const FieldLabel('Category'),
            ChoiceChips<ExpenseCategory>(options: ExpenseCategory.values, selected: _category, labelOf: (c) => c.label, iconOf: (c) => c.icon, onSelected: (c) => setState(() => _category = c)),
            const FieldLabel('Paid by'),
            PayMethodPicker(selected: _method, onSelected: (m) => setState(() => _method = m)),
            const SizedBox(height: 14),
            PickerField(
              label: 'Date',
              value: formatDate(_date),
              icon: AppIcons.event,
              onTap: () async {
                final d = await pickDate(context, initial: _date, first: DateTime(gym.today.year - 2), last: gym.today);
                if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, 12));
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(AppIcons.notes))),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                await gym.addExpense(category: _category, amount: parseAmount(_amount.text)!, date: _date, method: _method, note: _note.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  showMessage(context, '${_category.label} expense saved.');
                }
              },
              child: const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}
