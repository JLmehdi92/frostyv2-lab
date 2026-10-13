// Hype train payloads NOT observed live yet (TBC): written from the
// reverse-engineering notes (field names and casing as documented). Replace
// with real captures when such a train runs.

/// Realtime approaching (snake_case, deadlines keyed by events remaining).
const htTbcApproachingEvent =
    r'''{"type":"hype-train-approaching","data":{"approaching_hype_train_id":"approach-1","channel_id":"42","goal":3,"creator_color":"9147FF","events_remaining_durations":{"1":286,"2":120,"x":5},"participants":["900001"],"level_one_rewards":[{"type":"EMOTE","id":"emotesv2_00000000000000000000000000000001","token":"chanHype1"}],"is_golden_kappa_train":false,"is_treasure_train":false,"hype_train_type":"REGULAR"}}''';

/// GQL approaching (camelCase, eventsRemaining list).
const htTbcGqlApproaching =
    r'''{"data":{"user":{"id":"42","channel":{"id":"42","hypeTrain":{"execution":null,"approaching":{"id":"approach-1","goal":3,"creatorColor":"#9147FF","participants":[],"eventsRemaining":[{"events":1,"secondsRemaining":250}],"levelOneRewards":[{"id":"25","type":"EMOTE","emote":{"id":"25","token":"Kappa"}}],"isGoldenKappaTrain":false,"isTreasureTrain":false,"hypeTrainType":"TREASURE"}}}}}}''';

/// Realtime start (camelCase, PubSub config).
const htTbcStart =
    r'''{"type":"hype-train-start","data":{"id":"train-1","updatedAt":"2026-10-13T16:00:00Z","startedAt":"2026-10-13T16:00:00Z","expiresAt":"2026-10-13T16:05:00Z","endedAt":null,"endingReason":"IN_PROGRESS","conductors":[],"config":{"isEnabled":true,"kickoff":{"num_of_events":3,"min_points":100,"duration":300},"levelDuration":300,"cooldownDuration":3600,"difficulty":"EASY","difficultySettings":[{"difficulty":"EASY","maxLevel":392}],"conductorRewards":[],"participationConversionRates":[{"source":"SUBS","action":"TIER_1_SUB","value":500},{"source":"BITS","action":"CHEER","value":1}],"calloutEmoteId":"25","calloutEmoteToken":"Kappa"},"progress":{"level":{"value":1,"goal":1600,"rewards":[]},"goal":1600,"progression":1500,"total":1500,"remainingSeconds":299,"allTimeHighState":"NONE"},"isGoldenKappaTrain":false,"allTimeHigh":null,"sharedHypeTrainDetails":null,"isTreasureTrain":true,"treasureTrainDetails":{"discount_percentage":35,"discount_level_threshold":3,"discount_status":"APPROACHING"},"variantTrainDetails":null}}''';

/// GQL-shape execution of a community train at level 4.
const htTbcCommunity =
    r'''{"id":"train-2","isActive":true,"progress":{"level":{"value":4,"goal":9000,"rewards":[]},"goal":2500,"progression":100,"total":6600,"remainingSeconds":200,"allTimeHighState":"APPROACHING"},"config":{},"isGoldenKappaTrain":false,"isTreasureTrain":false,"variantTrainDetails":{"__typename":"CommunityTrainDetails","currentRewardAmount":0,"nextRewardAmount":20,"previousRewardAmount":0,"rewardLevelThreshold":null,"status":"APPROACHING"}}''';

/// GQL-shape execution of a mythic train.
const htTbcMythic =
    r'''{"id":"train-3","isActive":true,"progress":{"level":{"value":2,"goal":3400,"rewards":[]},"goal":1800,"progression":10,"total":1610,"remainingSeconds":250,"allTimeHighState":"NONE"},"config":{},"variantTrainDetails":{"__typename":"MythicTrainDetails","selectedEmote":null,"emotePool":[{"id":"emotesv2_00000000000000000000000000000001","token":"chanHype1"},{"id":"emotesv2_00000000000000000000000000000002","token":"chanHype2"}]}}''';

/// GQL-shape execution of a shared train between two channels.
const htTbcShared =
    r'''{"id":"train-4","isActive":true,"progress":{"level":{"value":3,"goal":5300,"rewards":[]},"goal":1900,"progression":950,"total":4350,"remainingSeconds":180,"allTimeHighState":"NONE"},"config":{},"sharedHypeTrainDetails":{"id":"shared-1","sharedConductors":[],"sharedProgress":[{"user":{"id":"42","login":"streamer","displayName":"Streamer"},"channelProgress":{"level":{"value":3,"goal":5300},"goal":1900,"progression":950,"total":3000}},{"user":{"id":"43","login":"friend","displayName":"Friend"},"channelProgress":{"level":{"value":3,"goal":5300},"goal":1900,"progression":950,"total":1350}}],"sharedAllTimeHighRecords":[{"user":{"id":"42","login":"streamer","displayName":"Streamer"},"channelAllTimeHigh":{"level":{"value":8},"goal":5000,"progression":2500,"total":25000}}]}}''';

/// Realtime shared merge.
const htTbcMerge =
    r'''{"type":"hype-train-shared-merge-trains","data":{"hypeTrain":{"id":"train-5","progress":{"level":{"value":4,"goal":9000,"rewards":[]},"goal":2500,"progression":300,"total":6800},"config":{}},"prevProgress":{"level":{"value":2,"goal":3400},"goal":1800,"progression":500,"total":2100},"prevUsers":[{"id":"42","login":"streamer","displayName":"Streamer"}],"joiningUsers":[{"id":"43","login":"friend","displayName":"Friend"}]}}''';

/// Realtime shared channel left.
const htTbcChannelLeft =
    r'''{"type":"hype-train-shared-channel-left","data":{"id":"train-5","user":{"id":"43","login":"friend","displayName":"Friend"},"shouldTrainEnd":false}}''';

/// Realtime shared conversion (treated as a start).
const htTbcConversion =
    r'''{"type":"hype-train-shared-conversion","data":{"hypeTrain":{"id":"train-6","progress":{"level":{"value":1,"goal":1600},"goal":1600,"progression":200,"total":200},"config":{}}}}''';
