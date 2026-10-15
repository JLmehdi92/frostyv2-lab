import 'package:flutter/material.dart';
import 'package:frosty/services/onset_updater.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/onset_update_prompt.dart';

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
    final result = await widget.updater.check(force: true);
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
    return ListTile(
      leading: const Icon(Icons.system_update_rounded),
      title: const Text('Check for updates'),
      subtitle: FutureBuilder<int>(
        future: _currentBuild,
        builder: (context, snapshot) =>
            Text(snapshot.hasData ? 'Build ${snapshot.data}' : ''),
      ),
      trailing: _checking
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _checking ? null : _check,
    );
  }
}
