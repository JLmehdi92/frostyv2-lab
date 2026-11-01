import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/stores/caption_store.dart';
import 'package:onset/utils/context_extensions.dart';

/// The player menu's captions: Twitch's "Closed Captions" switch, then the
/// stream's caption tracks to choose from when it offers more than one.
/// Their size and background are in Settings › Video.
class CaptionMenu extends StatelessWidget {
  const CaptionMenu({super.key, required this.captions});

  final CaptionStore captions;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(context.l10n.playerCaptions),
              subtitle: Text(context.l10n.liveCaptionsDetail),
              value: captions.enabled,
              onChanged: captions.setEnabled,
            ),
            for (final track in captions.choices)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                title: Text(track.nameIn(context.l10n)),
                trailing: captions.isSelected(track)
                    ? Icon(Icons.check_rounded, color: context.onsetColors.live)
                    : null,
                onTap: () => captions.selectTrack(track),
              ),
          ],
        );
      },
    );
  }
}
