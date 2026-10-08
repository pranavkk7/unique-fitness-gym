import 'package:flutter/foundation.dart';

import '../../models/models.dart';

/// What the Members tab should show when another screen opens it (e.g. a dashboard tile).
class MemberFilter {
  final MemberStatus? status;
  final bool onlyDue;

  const MemberFilter({this.status, this.onlyDue = false});

  static const all = MemberFilter();
}

class ShellTabs {
  ShellTabs._();

  static const home = 0;
  static const members = 1;
  static const checkIn = 2;
  static const reminders = 3;
  static const more = 4;
}

/// Remembers the open tab and lets any screen jump to another tab with a filter.
class ShellController extends ChangeNotifier {
  int _tab = ShellTabs.home;
  MemberFilter _memberFilter = MemberFilter.all;
  ReminderKind? _reminderKind;
  int _requestVersion = 0; // bumps on every request so the target tab can react even to the same value

  int get tab => _tab;
  MemberFilter get memberFilter => _memberFilter;
  ReminderKind? get reminderKind => _reminderKind;
  int get requestVersion => _requestVersion;

  void goTo(int tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }

  void openMembers([MemberFilter filter = MemberFilter.all]) {
    _memberFilter = filter;
    _requestVersion++;
    _tab = ShellTabs.members;
    notifyListeners();
  }

  void openReminders([ReminderKind? kind]) {
    _reminderKind = kind;
    _requestVersion++;
    _tab = ShellTabs.reminders;
    notifyListeners();
  }
}
