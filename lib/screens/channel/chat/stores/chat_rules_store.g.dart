// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_rules_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChatRulesStore on ChatRulesStoreBase, Store {
  Computed<bool>? _$mustShowBeforeChattingComputed;

  @override
  bool get mustShowBeforeChatting =>
      (_$mustShowBeforeChattingComputed ??= Computed<bool>(
        () => super.mustShowBeforeChatting,
        name: 'ChatRulesStoreBase.mustShowBeforeChatting',
      )).value;

  late final _$_rulesAtom = Atom(
    name: 'ChatRulesStoreBase._rules',
    context: context,
  );

  ChatRules? get rules {
    _$_rulesAtom.reportRead();
    return super._rules;
  }

  @override
  ChatRules? get _rules => rules;

  @override
  set _rules(ChatRules? value) {
    _$_rulesAtom.reportWrite(value, super._rules, () {
      super._rules = value;
    });
  }

  late final _$_acceptedVersionAtom = Atom(
    name: 'ChatRulesStoreBase._acceptedVersion',
    context: context,
  );

  @override
  int get _acceptedVersion {
    _$_acceptedVersionAtom.reportRead();
    return super._acceptedVersion;
  }

  @override
  set _acceptedVersion(int value) {
    _$_acceptedVersionAtom.reportWrite(value, super._acceptedVersion, () {
      super._acceptedVersion = value;
    });
  }

  late final _$_promptingAtom = Atom(
    name: 'ChatRulesStoreBase._prompting',
    context: context,
  );

  bool get prompting {
    _$_promptingAtom.reportRead();
    return super._prompting;
  }

  @override
  bool get _prompting => prompting;

  @override
  set _prompting(bool value) {
    _$_promptingAtom.reportWrite(value, super._prompting, () {
      super._prompting = value;
    });
  }

  late final _$ChatRulesStoreBaseActionController = ActionController(
    name: 'ChatRulesStoreBase',
    context: context,
  );

  @override
  void dismissPrompt() {
    final _$actionInfo = _$ChatRulesStoreBaseActionController.startAction(
      name: 'ChatRulesStoreBase.dismissPrompt',
    );
    try {
      return super.dismissPrompt();
    } finally {
      _$ChatRulesStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
mustShowBeforeChatting: ${mustShowBeforeChatting}
    ''';
  }
}
