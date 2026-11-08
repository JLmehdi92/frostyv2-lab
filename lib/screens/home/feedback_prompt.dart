import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/constants.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

const onsetFeedbackUrl = '$onsetRepoUrl/issues/new/choose';

abstract final class FeedbackPrompt {
  static const firstAskAfterOpens = 12;
  static const askAgainAfterOpens = 30;

  static bool due(SettingsStore settings) =>
      !settings.feedbackPromptDone &&
      settings.appOpens >= settings.feedbackPromptAtOpen;

  static void countOpen(SettingsStore settings) => runInAction(() {
    settings.appOpens++;
    if (settings.feedbackPromptAtOpen == 0) {
      settings.feedbackPromptAtOpen = firstAskAfterOpens;
    }
  });

  static void later(SettingsStore settings) => runInAction(
    () =>
        settings.feedbackPromptAtOpen = settings.appOpens + askAgainAfterOpens,
  );

  static void done(SettingsStore settings) =>
      runInAction(() => settings.feedbackPromptDone = true);
}

enum FeedbackChoice { send, later, never }

Future<FeedbackChoice?> showFeedbackPrompt(BuildContext context) =>
    showDialog<FeedbackChoice>(
      context: context,
      builder: (context) {
        final l = context.l10n;
        return OnsetDialog(
          title: l.feedbackPromptTitle,
          message: l.feedbackPromptMessage,
          actions: [
            SheetButton(
              key: const ValueKey('feedback-never'),
              label: l.feedbackPromptNever,
              tone: SheetButtonTone.text,
              onPressed: () => Navigator.pop(context, FeedbackChoice.never),
            ),
            SheetButton(
              key: const ValueKey('feedback-later'),
              label: l.feedbackPromptLater,
              tone: SheetButtonTone.text,
              onPressed: () => Navigator.pop(context, FeedbackChoice.later),
            ),
            SheetButton(
              key: const ValueKey('feedback-send'),
              label: l.feedbackPromptSend,
              onPressed: () => Navigator.pop(context, FeedbackChoice.send),
            ),
          ],
        );
      },
    );

Future<void> askForFeedbackIfDue(
  BuildContext context,
  SettingsStore settings, {
  required Future<void> Function(String url) openUrl,
}) async {
  if (!FeedbackPrompt.due(settings)) return;
  final choice = await showFeedbackPrompt(context);
  switch (choice) {
    case FeedbackChoice.send:
      FeedbackPrompt.done(settings);
      await openUrl(onsetFeedbackUrl);
    case FeedbackChoice.never:
      FeedbackPrompt.done(settings);
    case FeedbackChoice.later || null:
      FeedbackPrompt.later(settings);
  }
}
