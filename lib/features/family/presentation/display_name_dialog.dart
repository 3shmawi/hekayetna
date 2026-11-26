import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/ui/app_message.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The only rule for a name: 1 to 40 characters after trimming.
bool isValidDisplayName(String raw) {
  final t = raw.trim();
  return t.isNotEmpty && t.length <= 40;
}

/// "What does the family call you?" Prefilled with the current name.
/// Returns the saved name, or null if cancelled.
Future<String?> showDisplayNameDialog(
  BuildContext context,
  WidgetRef ref, {
  required String current,
}) async {
  final say = appMessenger(context);
  final savedMessage = context.l10n.displayNameSaved;
  final saved = await showDialog<String>(
    context: context,
    builder: (_) => _DisplayNameDialog(current: current, ref: ref),
  );
  if (saved != null) say(savedMessage);
  return saved;
}

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({required this.current, required this.ref});

  final String current;
  final WidgetRef ref;

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  late final _controller = TextEditingController(text: widget.current);
  bool _busy = false;
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!isValidDisplayName(_controller.text)) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _busy = true;
      _invalid = false;
    });
    final r = await widget.ref
        .read(familyRepositoryProvider)
        .setMyDisplayName(_controller.text);
    if (!mounted) return;
    switch (r) {
      case Success(:final value):
        unawaited(Analytics.capture('display_name_set'));
        Navigator.of(context).pop(value);
      case Failed():
        setState(() {
          _busy = false;
          _invalid = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.displayNameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => unawaited(_save()),
        decoration: InputDecoration(
          labelText: l10n.displayNameLabel,
          errorText: _invalid ? l10n.displayNameInvalid : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _busy ? null : () => unawaited(_save()),
          child: Text(l10n.displayNameSave),
        ),
      ],
    );
  }
}
