import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';

/// The wording of every WhatsApp message, with placeholders like {name} filled per member.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    const kinds = [ReminderKind.welcome, ReminderKind.expiring, ReminderKind.expired, ReminderKind.due, ReminderKind.birthday, ReminderKind.inactive, ReminderKind.followUp, ReminderKind.progress];
    return SubPage(
      title: 'Templates',
      subtitle: 'WhatsApp message wording',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          for (var i = 0; i < kinds.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => showAppSheet<void>(context, builder: (_) => _TemplateSheet(kind: kinds[i])),
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconBadge(kinds[i].icon, color: kinds[i].color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(kinds[i].label, style: AppText.title.copyWith(fontSize: 15.5)),
                        if (gym.settings.templates.texts.containsKey(kinds[i])) ...[const SizedBox(width: 8), Text('Edited', style: AppText.label.copyWith(fontSize: 9, color: AppColors.primaryBright))],
                      ]),
                      const SizedBox(height: 4),
                      Text(gym.settings.templates.of(kinds[i]), style: AppText.small.copyWith(color: AppColors.muted), maxLines: 3, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
              ),
            ).entrance(context, index: i),
        ],
      ),
    );
  }
}

class _TemplateSheet extends StatefulWidget {
  final ReminderKind kind;

  const _TemplateSheet({required this.kind});

  @override
  State<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends State<_TemplateSheet> {
  late final _text = TextEditingController(text: context.read<GymProvider>().settings.templates.of(widget.kind));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _insert(String placeholder) {
    final sel = _text.selection;
    final at = sel.isValid ? sel.start : _text.text.length;
    final end = sel.isValid ? sel.end : _text.text.length;
    _text.value = TextEditingValue(text: _text.text.replaceRange(at, end, placeholder), selection: TextSelection.collapsed(offset: at + placeholder.length));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final sample = gym.members.where(gym.isRunning).firstOrNull;
    final preview = sample == null
        ? _text.text
        : fillTemplate(_text.text, {
            '{name}': sample.firstName,
            '{gym}': gym.settings.gymName,
            '{plan}': gym.planById(sample.planId)?.name ?? 'membership',
            '{date}': '18 Oct 2026',
            '{days}': '3 days left',
            '{amount}': '₹500',
            '{code}': 'UFG-0012',
            '{phone}': gym.settings.phone,
          });
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(widget.kind.label, subtitle: 'Tap a placeholder to insert it. It is replaced with each member\'s details.'),
          TextField(controller: _text, maxLines: 6, minLines: 4, onChanged: (_) => setState(() {}), decoration: const InputDecoration(alignLabelWithHint: true, labelText: 'Message')),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in MessageTemplates.placeholders.entries) ActionChip(label: Text(e.key), tooltip: e.value, onPressed: () => _insert(e.key)),
          ]),
          const SizedBox(height: 16),
          Text('Preview', style: AppText.label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFF005C4B), borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(4), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
            child: Text(preview, style: AppText.body.copyWith(color: Colors.white)),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              await gym.updateSettings(gym.settings.copyWith(templates: gym.settings.templates.withText(widget.kind, _text.text)));
              if (context.mounted) {
                Navigator.pop(context);
                showMessage(context, 'Template saved.');
              }
            },
            child: const Text('Save template'),
          ),
          TextButton(
            onPressed: () => setState(() => _text.text = MessageTemplates.defaults[widget.kind]!),
            child: const Text('Reset to default'),
          ),
        ],
      ),
    );
  }
}
