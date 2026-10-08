import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// The Unique Fitness Gym badge. `logo_on_dark.png` is the official logo with its grey lettering
/// lifted for dark screens; `logo.png` is the untouched original (used on white receipts).
class BrandLogo extends StatelessWidget {
  final double height;

  const BrandLogo({super.key, this.height = 48});

  static const darkAsset = 'assets/brand/logo_on_dark.png';
  static const originalAsset = 'assets/brand/logo.png';
  static const aspect = 1024 / 852;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      darkAsset,
      height: height,
      width: height * aspect,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Unique Fitness Gym',
      // Should the asset ever be missing, show a simple mark instead of an error box.
      errorBuilder: (context, error, stack) => SizedBox(
        height: height,
        width: height * aspect,
        child: Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: height * 0.7),
      ),
    );
  }
}

/// Logo with the gym name and branch, for headers.
class BrandHeader extends StatelessWidget {
  final String branch;

  const BrandHeader({super.key, required this.branch});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandLogo(height: 44),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('UNIQUE FITNESS', style: AppText.headline.copyWith(fontSize: 19, height: 1, letterSpacing: 1)),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primaryBright),
                const SizedBox(width: 3),
                Text(branch.toUpperCase(), style: AppText.label.copyWith(fontSize: 10.5, color: AppColors.primaryBright, letterSpacing: 2)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
