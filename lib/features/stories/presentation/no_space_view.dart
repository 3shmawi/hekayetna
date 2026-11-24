import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/ui/app_message.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// First run: start a family space or join one with an invite code.
/// Spec 06 polishes invites.
class NoSpaceView extends StatefulWidget {
  const NoSpaceView({required this.onCreate, required this.onJoin, super.key});

  final Future<Result<FamilySpace>> Function(String name) onCreate;
  final Future<Result<FamilySpace>> Function(String code) onJoin;

  @override
  State<NoSpaceView> createState() => _NoSpaceViewState();
}

class _NoSpaceViewState extends State<NoSpaceView> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(
    TextEditingController field,
    Future<Result<FamilySpace>> Function(String) action,
  ) async {
    final text = field.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final result = await action(text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Failed(:final failure)) {
      showAppMessage(context, failure.message(context.l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.all(AppDimens.xl),
      children: [
        Icon(
          AdaptiveIcons.stories(context),
          size: AppDimens.iconMd * 2,
          color: scheme.primary,
        ),
        SizedBox(height: AppDimens.lg),
        Text(
          s.welcomeTitle,
          style: AppTextStyles.headline,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppDimens.md),
        Text(
          s.welcomeBody,
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppDimens.xl),
        AppSectionLabel(s.startSpaceTitle),
        SizedBox(height: AppDimens.md),
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: s.spaceName),
        ),
        SizedBox(height: AppDimens.md),
        AppButton.primary(
          label: s.createSpace,
          busy: _busy,
          onPressed: _busy ? null : () => _run(_name, widget.onCreate),
        ),
        SizedBox(height: AppDimens.xl),
        AppSectionLabel(s.joinSpaceTitle),
        SizedBox(height: AppDimens.sm),
        Text(
          s.joinSpaceHint,
          style: AppTextStyles.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: AppDimens.md),
        TextField(
          controller: _code,
          decoration: InputDecoration(labelText: s.inviteCode),
        ),
        SizedBox(height: AppDimens.md),
        AppButton.secondary(
          label: s.joinSpace,
          onPressed: _busy ? null : () => _run(_code, widget.onJoin),
        ),
      ],
    );
  }
}
