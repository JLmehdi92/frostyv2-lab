// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HomeStore on HomeStoreBase, Store {
  Computed<List<HomeFeed>>? _$feedsComputed;

  @override
  List<HomeFeed> get feeds => (_$feedsComputed ??= Computed<List<HomeFeed>>(
    () => super.feeds,
    name: 'HomeStoreBase.feeds',
  )).value;
  Computed<List<ActivityTab>>? _$activityTabsComputed;

  @override
  List<ActivityTab> get activityTabs =>
      (_$activityTabsComputed ??= Computed<List<ActivityTab>>(
        () => super.activityTabs,
        name: 'HomeStoreBase.activityTabs',
      )).value;
  Computed<bool>? _$canLeaveComputed;

  @override
  bool get canLeave => (_$canLeaveComputed ??= Computed<bool>(
    () => super.canLeave,
    name: 'HomeStoreBase.canLeave',
  )).value;

  late final _$_sectionAtom = Atom(
    name: 'HomeStoreBase._section',
    context: context,
  );

  ShellSection get section {
    _$_sectionAtom.reportRead();
    return super._section;
  }

  @override
  ShellSection get _section => section;

  @override
  set _section(ShellSection value) {
    _$_sectionAtom.reportWrite(value, super._section, () {
      super._section = value;
    });
  }

  late final _$_feedAtom = Atom(name: 'HomeStoreBase._feed', context: context);

  HomeFeed get feed {
    _$_feedAtom.reportRead();
    return super._feed;
  }

  @override
  HomeFeed get _feed => feed;

  @override
  set _feed(HomeFeed value) {
    _$_feedAtom.reportWrite(value, super._feed, () {
      super._feed = value;
    });
  }

  late final _$_activityTabAtom = Atom(
    name: 'HomeStoreBase._activityTab',
    context: context,
  );

  ActivityTab get activityTab {
    _$_activityTabAtom.reportRead();
    return super._activityTab;
  }

  @override
  ActivityTab get _activityTab => activityTab;

  @override
  set _activityTab(ActivityTab value) {
    _$_activityTabAtom.reportWrite(value, super._activityTab, () {
      super._activityTab = value;
    });
  }

  late final _$HomeStoreBaseActionController = ActionController(
    name: 'HomeStoreBase',
    context: context,
  );

  @override
  void _goToStart(bool loggedIn) {
    final _$actionInfo = _$HomeStoreBaseActionController.startAction(
      name: 'HomeStoreBase._goToStart',
    );
    try {
      return super._goToStart(loggedIn);
    } finally {
      _$HomeStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  bool selectSection(ShellSection section) {
    final _$actionInfo = _$HomeStoreBaseActionController.startAction(
      name: 'HomeStoreBase.selectSection',
    );
    try {
      return super.selectSection(section);
    } finally {
      _$HomeStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  bool selectFeed(HomeFeed feed) {
    final _$actionInfo = _$HomeStoreBaseActionController.startAction(
      name: 'HomeStoreBase.selectFeed',
    );
    try {
      return super.selectFeed(feed);
    } finally {
      _$HomeStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  bool selectActivityTab(ActivityTab tab) {
    final _$actionInfo = _$HomeStoreBaseActionController.startAction(
      name: 'HomeStoreBase.selectActivityTab',
    );
    try {
      return super.selectActivityTab(tab);
    } finally {
      _$HomeStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  bool handleBack() {
    final _$actionInfo = _$HomeStoreBaseActionController.startAction(
      name: 'HomeStoreBase.handleBack',
    );
    try {
      return super.handleBack();
    } finally {
      _$HomeStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
feeds: ${feeds},
activityTabs: ${activityTabs},
canLeave: ${canLeave}
    ''';
  }
}
