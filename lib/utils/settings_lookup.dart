import 'package:flutter/widgets.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:provider/provider.dart';

SettingsStore? maybeSettings(BuildContext context) {
  try {
    return Provider.of<SettingsStore>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

bool viewerCountsHidden(BuildContext context) =>
    maybeSettings(context)?.hideViewerCount ?? false;

bool featuredClipsOnly(BuildContext context) =>
    maybeSettings(context)?.clipDiscovery == ClipDiscovery.featured;
