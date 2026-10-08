import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/member_widgets.dart';
import '../../core/widgets/sub_page.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../admission/admission_screen.dart';
import '../shell/shell_controller.dart';
import 'member_profile_screen.dart';

enum _Filter { all, active, expiring, expired, frozen, dues, noFace }

enum _Sort { name, newest, ending }

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.name;
  int _seenRequest = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = context.read<ShellController>();
    if (shell.requestVersion != _seenRequest) {
      _seenRequest = shell.requestVersion;
      final f = shell.memberFilter;
      _filter = f.onlyDue
          ? _Filter.dues
          : switch (f.status) {
              MemberStatus.active => _Filter.active,
              MemberStatus.expiringSoon => _Filter.expiring,
              MemberStatus.expired => _Filter.expired,
              MemberStatus.frozen => _Filter.frozen,
              null => _Filter.all,
            };
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  MemberStatus? get _status => switch (_filter) {
        _Filter.active => MemberStatus.active,
        _Filter.expiring => MemberStatus.expiringSoon,
        _Filter.expired => MemberStatus.expired,
        _Filter.frozen => MemberStatus.frozen,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    var list = gym.searchMembers(query: _search.text, status: _status, onlyDue: _filter == _Filter.dues);
    if (_filter == _Filter.noFace) list = list.where((m) => gym.isRunning(m) && !m.faceEnrolled).toList();
    switch (_sort) {
      case _Sort.name:
        break;
      case _Sort.newest:
        list.sort((a, b) => b.number.compareTo(a.number));
      case _Sort.ending:
        list.sort((a, b) => a.endDate.compareTo(b.endDate));
    }
    final counts = {
      _Filter.all: gym.members.length,
      _Filter.active: gym.countWithStatus(MemberStatus.active),
      _Filter.expiring: gym.countWithStatus(MemberStatus.expiringSoon),
      _Filter.expired: gym.countWithStatus(MemberStatus.expired),
      _Filter.frozen: gym.countWithStatus(MemberStatus.frozen),
      _Filter.dues: gym.membersWithDue.length,
      _Filter.noFace: gym.members.where((m) => gym.isRunning(m) && !m.faceEnrolled).length,
    };
    const labels = {
      _Filter.all: 'All',
      _Filter.active: 'Active',
      _Filter.expiring: 'Expiring',
      _Filter.expired: 'Expired',
      _Filter.frozen: 'Frozen',
      _Filter.dues: 'Dues',
      _Filter.noFace: 'No Face ID',
    };

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RevealText('Members', style: AppText.display),
                        Text('${counts[_Filter.active]} active · ${counts[_Filter.expiring]} expiring · ${gym.members.length} total', style: AppText.small.copyWith(color: AppColors.muted)),
                      ],
                    ),
                  ),
                  PopupMenuButton<_Sort>(
                    tooltip: 'Sort',
                    icon: const Icon(AppIcons.sort),
                    initialValue: _sort,
                    onSelected: (s) => setState(() => _sort = s),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _Sort.name, child: Text('Name A to Z')),
                      PopupMenuItem(value: _Sort.newest, child: Text('Newest first')),
                      PopupMenuItem(value: _Sort.ending, child: Text('Ending soonest')),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search name, phone or UFG code',
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(AppIcons.close),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _filter == f,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _filter = f);
                        },
                        label: Text('${labels[f]}  ${counts[f]}'),
                        labelStyle: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w700, color: _filter == f ? Colors.white : AppColors.text),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                child: list.isEmpty
                    ? EmptyState(
                        key: const ValueKey('empty'),
                        icon: gym.hasMembers ? AppIcons.searchOff : AppIcons.groupAdd,
                        title: gym.hasMembers ? 'No members match' : 'No members yet',
                        subtitle: gym.hasMembers ? 'Try another search or filter.' : 'Start with a new admission.',
                        actionLabel: gym.hasMembers ? null : 'New admission',
                        onAction: () => openPage(context, const AdmissionScreen()),
                      )
                    : ListView.builder(
                        key: ValueKey('${_filter.name}-${_sort.name}'),
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 150),
                        itemCount: list.length,
                        itemBuilder: (context, i) => MemberTile(
                          member: list[i],
                          onTap: () => openPage(context, MemberProfileScreen(memberId: list[i].id)),
                        ).entrance(context, index: i),
                      ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 18,
          bottom: MediaQuery.sizeOf(context).width >= 840 ? 24 : MediaQuery.paddingOf(context).bottom + 104,
          child: FloatingActionButton.extended(
            heroTag: 'admit-fab',
            tooltip: 'New admission',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => openPage(context, const AdmissionScreen()),
            icon: const Icon(AppIcons.personAdd),
            label: const Text('Admission', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          ),
        ),
      ],
    );
  }
}
