import 'dart:math' as math;

import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _moneyCompact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);

String formatMoney(num value) => _money.format(value);

String formatMoneyCompact(num value) => value.abs() < 1000 ? _money.format(value) : _moneyCompact.format(value);

String formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

String formatDayMonth(DateTime d) => DateFormat('d MMM').format(d);

String formatTime(DateTime d) => DateFormat('h:mm a').format(d);

String formatMonthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

String formatShortMonth(DateTime d) => DateFormat('MMM').format(d);

String formatWeekday(DateTime d) => DateFormat('EEEE').format(d);

/// "2026-10-15", for exports.
String isoDay(DateTime d) => d.toIso8601String().substring(0, 10);

/// "+12%" / "-4%" for a change fraction.
String formatChange(double fraction) => '${fraction >= 0 ? '+' : '−'}${(fraction.abs() * 100).round()}%';

/// "Today", "Yesterday", "3 days ago" or a date.
String relativeDay(DateTime day, DateTime today) {
  final diff = dateOnly(today).difference(dateOnly(day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return '$diff days ago';
  if (diff == -1) return 'Tomorrow';
  return formatDayMonth(day);
}

/// Midnight of the given day, used to compare dates without the time part.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

/// Adds calendar months and keeps the day inside the month (31 Jan + 1 month = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final target = DateTime(d.year, d.month + months, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, d.day > lastDay ? lastDay : d.day);
}

/// "SK" for "Sandeep Kumar", "P" for "Pranav".
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// Keeps digits only: "+91 95622 77010" -> "919562277010".
String digitsOnly(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

/// Phone number with country code for wa.me links. Assumes India (+91) for 10-digit numbers.
String whatsappNumber(String phone) {
  final d = digitsOnly(phone);
  return d.length == 10 ? '91$d' : d;
}

String memberCode(int number) => 'UFG-${number.toString().padLeft(4, '0')}';

/// 17:30 (as 1050 minutes after midnight) -> "5:30 PM".
String minutesLabel(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

/// A "nice" axis step (1, 2 or 5 times a power of ten) that gives about [ticks] gridlines up to [max],
/// so chart axes land on clean numbers like 5,000 / 10,000.
double niceStep(double max, [int ticks = 4]) {
  if (max <= 0) return 1;
  final raw = max / ticks;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final residual = raw / magnitude;
  final nice = residual <= 1
      ? 1
      : residual <= 2
          ? 2
          : residual <= 5
              ? 5
              : 10;
  return nice * magnitude;
}
