import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/gym_provider.dart';
import 'format.dart';

void showMessage(BuildContext context, String text, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(text),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}

Future<bool> _open(BuildContext context, Uri uri, String failure) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) showMessage(context, failure);
  return ok;
}

/// Opens WhatsApp with [text] ready to send to [phone]. Nothing is sent until the person taps send
/// in WhatsApp. Returns false if WhatsApp could not be opened.
Future<bool> openWhatsApp(BuildContext context, String phone, String text) {
  if (_isDemo(context)) return _demoPreview(context, 'WhatsApp to $phone', text);
  final number = whatsappNumber(phone);
  if (number.length < 10) {
    showMessage(context, 'No valid phone number saved.');
    return Future.value(false);
  }
  return _open(context, Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}'), 'Could not open WhatsApp.');
}

Future<bool> callNumber(BuildContext context, String phone) {
  if (_isDemo(context)) {
    showMessage(context, 'Demo data: calls are switched off. With real members this rings $phone.');
    return Future.value(false);
  }
  final number = digitsOnly(phone);
  if (number.isEmpty) {
    showMessage(context, 'No phone number saved.');
    return Future.value(false);
  }
  return _open(context, Uri(scheme: 'tel', path: number), 'Could not start the call.');
}

bool _isDemo(BuildContext context) {
  try {
    return context.read<GymProvider>().settings.demoData;
  } on ProviderNotFoundException {
    return false;
  }
}

/// In demo mode, shows the message that WhatsApp would open with. Returns true so flows like
/// "Send all" behave exactly as they would for real.
Future<bool> _demoPreview(BuildContext context, String title, String text) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title.toUpperCase()),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Color(0xFF005C4B), borderRadius: BorderRadius.all(Radius.circular(14))),
          child: Text(text.isEmpty ? '(blank message)' : text, style: const TextStyle(color: Colors.white, height: 1.35)),
        ),
        const SizedBox(height: 12),
        const Text('Demo data: nothing is sent. With real members this opens WhatsApp with the message ready.'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
    ),
  );
  return true;
}

Future<bool> openLink(BuildContext context, String url) => _open(context, Uri.parse(url), 'Could not open the link.');

Future<void> copyText(BuildContext context, String text, {String done = 'Copied'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showMessage(context, done);
}

/// Shares plain text through the share sheet, for example to a batch's WhatsApp group.
Future<void> shareText(BuildContext context, String text, {String? subject}) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  } catch (_) {
    if (context.mounted) showMessage(context, 'Sharing is not available on this device.');
  }
}

/// Shares a text file (CSV, backup) through the phone's share sheet: Drive, WhatsApp, email.
Future<void> shareFile(BuildContext context, {required String name, required String content, required String mimeType, String? subject}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  try {
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, name: name, mimeType: mimeType)], fileNameOverrides: [name], subject: subject));
  } catch (_) {
    if (context.mounted) showMessage(context, 'Sharing is not available on this device.');
  }
}
