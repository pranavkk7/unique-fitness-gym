import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../providers/gym_provider.dart';

/// Who made the app and what it is built with.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const developer = 'Pranav KK';
  static const email = 'pranavvinod508@gmail.com';
  static const github = 'https://github.com/pranavkk7';
  static const linkedin = 'https://linkedin.com/in/pranavkk';
  static const version = '2.0';

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    const stack = ['Flutter', 'Dart', 'Material 3', 'Provider', 'Hive', 'eSSL / ZK protocol', 'fl_chart', 'Custom painters', 'PDF', 'WhatsApp links'];
    return SubPage(
      title: 'About',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Center(child: const BrandLogo(height: 120).entrance(context)),
          const SizedBox(height: 14),
          Text('${gym.settings.gymName.toUpperCase()}\nFRONT DESK', textAlign: TextAlign.center, style: AppText.display.copyWith(fontSize: 30)).entrance(context, index: 1),
          const SizedBox(height: 6),
          Text('Version $version · ${gym.settings.branchName} branch', textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.muted)),
          const SizedBox(height: 26),
          AppCard(
            gradient: AppColors.redGradient,
            glow: true,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DESIGNED & DEVELOPED BY', style: AppText.label.copyWith(color: Colors.white70, letterSpacing: 2.4)),
                const SizedBox(height: 6),
                Text(developer.toUpperCase(), style: AppText.display.copyWith(fontSize: 52, height: 0.95)),
                // A red line draws itself under the name.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 1200),
                  curve: Motion.settle,
                  builder: (context, t, _) => Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 140 * t,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Python & AI developer from Bengaluru, formerly a planning engineer. Built this app for Unique Fitness Gym, Pinarayi.',
                  style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: Colors.white, fontSize: 15, height: 1.4, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _LinkChip(icon: Icons.mail_rounded, label: 'Email', onTap: () => openLink(context, 'mailto:$email')),
                  _LinkChip(icon: Icons.code_rounded, label: 'GitHub', onTap: () => openLink(context, github)),
                  _LinkChip(icon: Icons.work_rounded, label: 'LinkedIn', onTap: () => openLink(context, linkedin)),
                ]),
              ],
            ),
          ).entrance(context, index: 2),
          const SectionHeader('Built with'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < stack.length; i++)
              Chip(label: Text(stack[i]), labelStyle: AppText.small.copyWith(color: AppColors.text, fontWeight: FontWeight.w700)).entrance(context, index: i),
          ]),
          const SectionHeader('Privacy'),
          const AppCard(
            child: Text(
              'Member data stays on the gym\'s own phone or tablet. The app talks only to the gym\'s Face ID device on the local Wi-Fi; WhatsApp, calls and sharing open the phone\'s own apps.',
              style: AppText.bodyMuted,
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text('© 2026 $developer · Logo and brand © Unique Fitness Gym', style: AppText.small.copyWith(color: AppColors.muted))),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LinkChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
