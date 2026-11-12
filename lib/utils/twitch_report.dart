final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

Uri? twitchReportUri(String login) => _login.hasMatch(login)
    ? Uri.https('www.twitch.tv', '/${login.toLowerCase()}/report')
    : null;

Uri? twitchModViewUri(String login) => _login.hasMatch(login)
    ? Uri.https('www.twitch.tv', '/moderator/${login.toLowerCase()}')
    : null;
