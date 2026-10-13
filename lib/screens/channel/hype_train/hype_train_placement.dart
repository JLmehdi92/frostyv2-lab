/// Where the hype train shows on the channel screen.
enum HtPlacement {
  /// Above chat, full banner (portrait, chat-only, vertical landscape).
  bannerFull,

  /// Above the narrow landscape chat (side column or overlay).
  bannerCompact,

  /// Chat is hidden in landscape full screen: a pill over the video.
  pill,

  /// The landscape keyboard leaves no room (phones).
  none,
}

HtPlacement hypeTrainPlacement({
  required bool landscape,
  required bool forceVertical,
  required bool fullScreen,
  required bool overlayChat,
  required bool showVideo,
  required bool keyboardOpen,
  required bool largeScreen,
}) {
  // A tablet keeps plenty of chat above the landscape keyboard.
  final keyboardHides = keyboardOpen && !largeScreen;
  if (!showVideo) {
    return landscape && keyboardHides
        ? HtPlacement.none
        : HtPlacement.bannerFull;
  }
  if (!landscape || forceVertical) return HtPlacement.bannerFull;
  if (keyboardHides) return HtPlacement.none;
  if (fullScreen) {
    return overlayChat ? HtPlacement.bannerCompact : HtPlacement.pill;
  }
  return HtPlacement.bannerCompact;
}
