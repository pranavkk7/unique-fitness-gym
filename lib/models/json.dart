/// Small helpers for reading saved JSON safely. Older or hand-edited data may miss fields, so every
/// reader has a fallback instead of throwing.
library;

/// Reads an enum by name, falling back to [fallback] for unknown or missing values.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime? dateOrNull(Object? value) => value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

DateTime dateOr(Object? value, DateTime fallback) => dateOrNull(value) ?? fallback;

double? doubleOrNull(Object? value) => value is num ? value.toDouble() : null;

double doubleOr(Object? value, [double fallback = 0]) => value is num ? value.toDouble() : fallback;

int intOr(Object? value, [int fallback = 0]) => value is num ? value.toInt() : fallback;

String str(Object? value, [String fallback = '']) => value is String ? value : fallback;

String? strOrNull(Object? value) => value is String && value.isNotEmpty ? value : null;

/// ISO date (yyyy-mm-dd) for date-only fields, so saved files stay readable.
String? isoDate(DateTime? d) => d?.toIso8601String().substring(0, 10);

List<Map<String, dynamic>> mapList(Object? value) =>
    value is List ? [for (final e in value) if (e is Map) Map<String, dynamic>.from(e)] : const [];
