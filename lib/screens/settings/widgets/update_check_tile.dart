import 'package:flutter/material.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/services/onset_updater.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/alert_message.dart';
import 'package:onset/widgets/onset_update_prompt.dart';

/// "Check for updates": shows the installed build and looks for a newer one
/// right away, whatever the last automatic check found.
class UpdateCheckTile extends StatefulWidget {
  final OnsetUpdater updater;

  const UpdateCheckTile({super.key, required this.updater});

  @override
  State<UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<UpdateCheckTile> {
  late final _currentBuild = widget.updater.currentBuild();
  var _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    UpdateCheck result;
    try {
      result = await widget.updater.check(force: true);
    } catch (e) {
      debugPrint('Update check failed: ${e.runtimeType}');
      result = const UpdateCheckFailed();
    }
    if (!mounted) return;
    setState(() => _checking = false);

    switch (result) {
      case UpdateAvailable():
        await offerUpdate(context, widget.updater, result);
      case UpToDate():
        _tell("You're up to date");
      case UpdateCheckFailed():
        _tell("Couldn't check for updates");
      case UpdateCheckSkipped():
        break;
    }
  }

  void _tell(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AlertMessage(message: message, centered: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return SettingsRow(
      glyph: SettingsGlyphKind.update,
      title: 'Check for updates',
      subtitle: FutureBuilder<int>(
        future: _currentBuild,
        builder: (context, snapshot) => Text(
          snapshot.hasData ? 'Build ${snapshot.data}' : '',
          style: OnsetType.tabular(const TextStyle()),
        ),
      ),
      trailing: _checking
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SettingsColors.accentOf(context),
                backgroundColor: colors.buttonRing,
                semanticsLabel: 'Checking',
              ),
            )
          : null,
      onTap: _checking ? null : _check,
    );
  }
}
