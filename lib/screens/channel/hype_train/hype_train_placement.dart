/// Where the hype train shows on the channel screen.
enum HtPlacement {
  /// Above chat, full banner (portrait, chat-only, vertical landscape).
  bannerFull,

  /// Above the narrow landscape chat (side column or overlay).
  bannerCompact,

  /// Chat is hidden in landscape full screen: a pill over the video.
  pill,

  /// The landscape keyboard leaves no room.
  none,
}

HtPlacement hypeTrainPlacement({
  required bool landscape,
  required bool forceVertical,
  required bool fullScreen,
  required bool overlayChat,
  required bool showVideo,
  required bool keyboardOpen,
}) {
  if (!showVideo) {
    return landscape && keyboardOpen
        ? HtPlacement.none
        : HtPlacement.bannerFull;
  }
  if (!landscape || forceVertical) return HtPlacement.bannerFull;
  if (keyboardOpen) return HtPlacement.none;
  if (fullScreen) {
    return overlayChat ? HtPlacement.bannerCompact : HtPlacement.pill;
  }
  return HtPlacement.bannerCompact;
}
