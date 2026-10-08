import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'motion_widgets.dart';
import 'surfaces.dart';

/// Layout for pages opened from a tab: back button, big poster title, optional actions, and a
/// body. Content is centred and capped in width so it also looks right on a front-desk tablet.
class SubPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final Widget? floatingAction;
  final Widget? bottom;
  final double maxWidth;

  const SubPage({super.key, required this.title, this.subtitle, this.actions = const [], required this.child, this.floatingAction, this.bottom, this.maxWidth = 760});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingAction,
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 12, 2),
                    child: Row(
                      children: [
                        IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: RevealText(title.toUpperCase(), style: AppText.display.copyWith(fontSize: 28))),
                              if (subtitle != null) Text(subtitle!, style: AppText.small.copyWith(color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        ...actions,
                      ],
                    ),
                  ),
                  Expanded(child: child),
                  ?bottom,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens [page] with a fade-and-rise transition used across the app.
Future<T?> openPage<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// A bottom sheet in the app's style that grows with its content.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scrollable = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollable,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: builder(sheetContext),
    ),
  );
}

/// Asks before doing something that cannot be undone. Returns true if confirmed.
Future<bool> confirmAction(BuildContext context, {required String title, required String message, String confirmLabel = 'Delete', bool destructive = true}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title.toUpperCase()),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)) : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Header block inside a sheet: poster title and a muted line.
class SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SheetHeader(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppText.headline),
          if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: AppText.bodyMuted)],
        ],
      ),
    );
  }
}

/// A card with a section header used in detail pages.
class DetailCard extends StatelessWidget {
  final List<Widget> children;

  const DetailCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) => AppCard(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Column(children: children));
}
