import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
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
      originalAsset,
      height: height,
      width: height * aspect,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Unique Fitness Gym',
      // Should the asset ever be missing, show a simple mark instead of an error box.
      errorBuilder: (context, error, stack) => SizedBox(
        height: height,
        width: height * aspect,
        child: Icon(
          AppIcons.barbell,
          color: AppColors.primary,
          size: height * 0.7,
        ),
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
        const BrandLogo(height: 40),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unique Fitness',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.headline.copyWith(fontSize: 16, height: 1.1),
              ),
              const SizedBox(height: 2),
              Text(
                branch,
                style: AppText.small.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
