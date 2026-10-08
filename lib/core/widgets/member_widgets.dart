import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/format.dart';
import 'basics.dart';
import 'surfaces.dart';

/// Colour, label and icon for a membership status, used everywhere.
class StatusStyle {
  final Color color;
  final String label;
  final IconData icon;

  const StatusStyle(this.color, this.label, this.icon);

  static StatusStyle of(GymProvider gym, Member m) {
    final left = gym.daysLeft(m);
    switch (gym.statusOf(m)) {
      case MemberStatus.active:
        return const StatusStyle(AppColors.success, 'Active', Icons.check_circle_rounded);
      case MemberStatus.expiringSoon:
        return StatusStyle(AppColors.warning, left == 0 ? 'Ends today' : '$left day${left == 1 ? '' : 's'} left', Icons.schedule_rounded);
      case MemberStatus.expired:
        return const StatusStyle(AppColors.danger, 'Expired', Icons.cancel_rounded);
      case MemberStatus.frozen:
        return const StatusStyle(AppColors.frozen, 'Frozen', Icons.ac_unit_rounded);
    }
  }

  static const forStatus = {
    MemberStatus.active: StatusStyle(AppColors.success, 'Active', Icons.check_circle_rounded),
    MemberStatus.expiringSoon: StatusStyle(AppColors.warning, 'Expiring', Icons.schedule_rounded),
    MemberStatus.expired: StatusStyle(AppColors.danger, 'Expired', Icons.cancel_rounded),
    MemberStatus.frozen: StatusStyle(AppColors.frozen, 'Frozen', Icons.ac_unit_rounded),
  };
}

/// Member photo (or initials) in a ring of their status colour. Wrapped in a [Hero] so it flies
/// from the list into the profile.
class MemberAvatar extends StatelessWidget {
  final Member member;
  final double size;
  final Color? ringColor;
  final bool hero;
  final String heroTag;

  const MemberAvatar({super.key, required this.member, this.size = 48, this.ringColor, this.hero = true, this.heroTag = ''});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final ring = ringColor ?? StatusStyle.of(gym, member).color;
    final avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.055),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: size * 0.045)),
      child: ClipOval(child: _Face(member: member, size: size)),
    );
    if (!hero) return avatar;
    return Hero(tag: 'avatar-${member.id}$heroTag', child: avatar);
  }
}

class _Face extends StatelessWidget {
  final Member member;
  final double size;

  const _Face({required this.member, required this.size});

  Widget _initials() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceHigher, AppColors.surfaceHigh]),
        ),
        alignment: Alignment.center,
        child: Text(initials(member.name), style: TextStyle(fontFamily: AppText.displayFont, fontStyle: FontStyle.italic, fontWeight: FontWeight.w800, fontSize: size * 0.36, color: AppColors.text)),
      );

  Widget _image(Uint8List bytes) => Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: (size * 3).round());

  @override
  Widget build(BuildContext context) {
    if (!member.hasPhoto) return _initials();
    final gym = context.read<GymProvider>();
    final cached = gym.cachedPhoto(member.id);
    if (cached != null) return _image(cached);
    return FutureBuilder<Uint8List?>(
      future: gym.loadPhoto(member.id),
      builder: (context, snap) => snap.data == null ? _initials() : _image(snap.data!),
    );
  }
}

/// One member row: avatar, name, code and plan, and a status pill (or a custom [trailing]).
class MemberTile extends StatelessWidget {
  final Member member;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;

  const MemberTile({super.key, required this.member, this.onTap, this.trailing, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final style = StatusStyle.of(gym, member);
    final plan = gym.planById(member.planId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        radius: 20,
        child: Row(
          children: [
            MemberAvatar(member: member, size: 48),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name, style: AppText.title.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    subtitle ?? '${memberCode(member.number)}  ·  ${plan?.name ?? 'No plan'}',
                    style: AppText.small.copyWith(color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusPill(style.label, color: style.color, icon: style.icon),
                    if (member.balanceDue > 0) ...[
                      const SizedBox(height: 6),
                      Text('Due ${formatMoney(member.balanceDue)}', style: AppText.small.copyWith(color: AppColors.danger, fontWeight: FontWeight.w800)),
                    ],
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
