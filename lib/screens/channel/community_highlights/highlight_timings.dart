/// How often frequent updates (poll votes, prediction points, raid
/// viewers) reach the screen at most.
const kHighlightCommitInterval = Duration(milliseconds: 500);

/// How long a finished poll's results stay up (Twitch archives it after
/// about 60 s).
const kPollResultLinger = Duration(seconds: 60);

/// How long a resolved prediction stays up.
const kPredictionResolvedLinger = Duration(seconds: 60);

/// How long a canceled prediction stays up.
const kPredictionCanceledLinger = Duration(seconds: 30);

/// A resolved prediction older than this (GQL keeps the last one for days)
/// is not shown.
const kPredictionResolvedMaxAge = Duration(minutes: 2);

/// How long the raid card stays after the raid left.
const kRaidAfterGoLinger = Duration(seconds: 60);

/// How long a raid called off says so before it goes away.
const kRaidCancelledLinger = Duration(seconds: 3);

/// How long past its own departure time a raid that never said "go" or
/// "cancel" (a lost event) stays up.
const kRaidMissedGoMargin = Duration(seconds: 30);

/// GQL polling while realtime is unavailable.
const kHighlightPollFallback = Duration(seconds: 30);

/// Minimum gap between two GQL fetches of one kind.
const kHighlightRefetchGap = Duration(seconds: 2);

/// How long an incoming raid stays pinned above chat.
const kIncomingRaidPin = Duration(milliseconds: 6500);

/// One raider's raid heard twice within this (its notice, and the raid the
/// viewer followed here) pins once.
const kIncomingRaidRepeat = Duration(minutes: 2);
