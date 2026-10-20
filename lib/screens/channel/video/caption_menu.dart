import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/video/stores/caption_store.dart';
import 'package:frosty/utils/context_extensions.dart';

/// The player menu's captions: Twitch's "Closed Captions" switch, then the
/// stream's caption tracks to choose from when it offers more than one.
/// Their size and background are in Settings › Video.
class CaptionMenu extends StatelessWidget {
  const CaptionMenu({super.key, required this.captions});

  final CaptionStore captions;

  @override
  Widget build(BuildContext context) {
    final settings = captions.settings;
    return Observer(
      builder: (context) {
        final on = settings.showCaptions;
        final tracks = captions.tracks;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Closed Captions'),
              subtitle: const Text('When the stream has them'),
              value: on,
              onChanged: (value) => settings.showCaptions = value,
            ),
            if (on && tracks.length > 1)
              for (final track in tracks)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  title: Text(track.name),
                  trailing: captions.selectedTrackId == track.id
                      ? Icon(
                          Icons.check_rounded,
                          color: context.frostyColors.live,
                        )
                      : null,
                  onTap: () => captions.selectTrack(track),
                ),
          ],
        );
      },
    );
  }
}
