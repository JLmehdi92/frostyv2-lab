// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caption_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CaptionStore on CaptionStoreBase, Store {
  late final _$_captionAtom = Atom(
    name: 'CaptionStoreBase._caption',
    context: context,
  );

  String? get caption {
    _$_captionAtom.reportRead();
    return super._caption;
  }

  @override
  String? get _caption => caption;

  @override
  set _caption(String? value) {
    _$_captionAtom.reportWrite(value, super._caption, () {
      super._caption = value;
    });
  }

  late final _$_tracksAtom = Atom(
    name: 'CaptionStoreBase._tracks',
    context: context,
  );

  List<CaptionTrack> get tracks {
    _$_tracksAtom.reportRead();
    return super._tracks;
  }

  @override
  List<CaptionTrack> get _tracks => tracks;

  @override
  set _tracks(List<CaptionTrack> value) {
    _$_tracksAtom.reportWrite(value, super._tracks, () {
      super._tracks = value;
    });
  }

  late final _$_selectedTrackIdAtom = Atom(
    name: 'CaptionStoreBase._selectedTrackId',
    context: context,
  );

  String? get selectedTrackId {
    _$_selectedTrackIdAtom.reportRead();
    return super._selectedTrackId;
  }

  @override
  String? get _selectedTrackId => selectedTrackId;

  @override
  set _selectedTrackId(String? value) {
    _$_selectedTrackIdAtom.reportWrite(value, super._selectedTrackId, () {
      super._selectedTrackId = value;
    });
  }

  late final _$CaptionStoreBaseActionController = ActionController(
    name: 'CaptionStoreBase',
    context: context,
  );

  @override
  void selectTrack(CaptionTrack track) {
    final _$actionInfo = _$CaptionStoreBaseActionController.startAction(
      name: 'CaptionStoreBase.selectTrack',
    );
    try {
      return super.selectTrack(track);
    } finally {
      _$CaptionStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
