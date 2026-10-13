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

/// GQL polling while realtime is unavailable.
const kHighlightPollFallback = Duration(seconds: 30);

/// Minimum gap between two GQL fetches of one kind.
const kHighlightRefetchGap = Duration(seconds: 2);
