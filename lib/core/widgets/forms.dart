import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/motion.dart';
import '../utils/format.dart';

/// Small upper-case caption above a form field or group.
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 9, left: 2),
        child: Text(text.toUpperCase(), style: AppText.label),
      );
}

/// A row of selectable chips for picking one value.
class ChoiceChips<T> extends StatelessWidget {
  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final IconData Function(T)? iconOf;

  const ChoiceChips({super.key, required this.options, required this.selected, required this.labelOf, required this.onSelected, this.iconOf});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            selected: o == selected,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              onSelected(o);
            },
            avatar: iconOf == null ? null : Icon(iconOf!(o), size: 16, color: o == selected ? Colors.white : AppColors.muted),
            label: Text(labelOf(o)),
            labelStyle: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: o == selected ? Colors.white : AppColors.text, fontWeight: FontWeight.w700, fontSize: 13.5),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          ),
      ],
    );
  }
}

/// A tappable field that shows a value (like a date) and opens a picker.
class PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const PickerField({super.key, required this.label, required this.value, required this.icon, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: value != null && onClear != null ? IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear) : null,
        ),
        child: Text(value ?? '', style: AppText.body),
      ),
    );
  }
}

/// Parses "1,500" or "1500.50"; null for blank or invalid input.
double? parseAmount(String text) => double.tryParse(text.trim().replaceAll(',', '').replaceAll('₹', ''));

String? validatePhone(String? v) {
  final d = digitsOnly(v ?? '');
  if (d.length == 10 || (d.length == 12 && d.startsWith('91'))) return null;
  return 'Enter a valid 10-digit number';
}

String? requiredText(String? v, String message) => (v == null || v.trim().isEmpty) ? message : null;

/// Date picker themed for the app.
Future<DateTime?> pickDate(BuildContext context, {required DateTime initial, required DateTime first, required DateTime last, String? help}) {
  return showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last, helpText: help);
}

/// A big money field with a rupee prefix.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const AmountField({super.key, required this.controller, required this.label, this.validator, this.onChanged, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: AppText.headline.copyWith(fontSize: 22, fontStyle: FontStyle.normal, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800),
      decoration: InputDecoration(labelText: label, prefixText: '₹ ', prefixStyle: AppText.title.copyWith(color: AppColors.muted)),
      validator: validator,
      onChanged: onChanged,
    );
  }
}

/// Step dots for a multi-step form; the current step stretches into a pill.
class StepDots extends StatelessWidget {
  final int count;
  final int current;

  const StepDots({super.key, required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.settle,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= current ? AppColors.primary : AppColors.surfaceHigher,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
