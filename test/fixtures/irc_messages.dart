/// Test fixtures containing real Twitch IRC message samples.
/// These are used to test the IRC message parsing logic.
library;

/// A basic chat message (PRIVMSG) with standard tags
const basicPrivmsg =
    '@badge-info=;badges=;color=#FF0000;display-name=TestUser;emotes=;'
    'id=abc123-def456;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=67890;user-type= '
    ':testuser!testuser@testuser.tmi.twitch.tv PRIVMSG #channel :Hello World';

/// A chat message with emotes in the tags
/// Note: emote positions are 0-indexed byte positions in the message
/// "Kappa LUL" - Kappa is at 0-4, LUL is at 6-8
const privmsgWithEmotes =
    '@badge-info=subscriber/12;badges=subscriber/12,premium/1;'
    'color=#1E90FF;display-name=EmoteUser;'
    'emotes=25:0-4/1902:6-8;id=msg-id-123;mod=0;room-id=12345;'
    'subscriber=1;tmi-sent-ts=1234567890123;turbo=0;user-id=11111;user-type= '
    ':emoteuser!emoteuser@emoteuser.tmi.twitch.tv PRIVMSG #channel :Kappa LUL';

/// A chat message with multiple instances of the same emote
const privmsgWithMultipleEmotes =
    '@badge-info=;badges=;color=#00FF00;display-name=MultiEmote;'
    'emotes=25:0-4,11-15;id=msg-456;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=22222;user-type= '
    ':multiemote!multiemote@multiemote.tmi.twitch.tv PRIVMSG #channel :Kappa test Kappa';

/// An IRC /me action message
const actionMessage =
    '@badge-info=;badges=broadcaster/1;color=#8A2BE2;display-name=Broadcaster;'
    'emotes=;id=action-123;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=12345;user-type= '
    ':broadcaster!broadcaster@broadcaster.tmi.twitch.tv PRIVMSG #channel '
    ':\x01ACTION is testing\x01';

/// A message that mentions another user
const mentionMessage =
    '@badge-info=;badges=;color=#FF6347;display-name=Mentioner;emotes=;'
    'id=mention-123;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=33333;user-type= '
    ':mentioner!mentioner@mentioner.tmi.twitch.tv PRIVMSG #channel :@targetuser hello!';

/// A message with escaped spaces in tags (\\s represents a space)
const messageWithEscapedSpaces =
    '@badge-info=subscriber/12\\smonths;badges=subscriber/12;color=#FF0000;'
    'display-name=EscapeTest;emotes=;id=escape-123;mod=0;room-id=12345;'
    'subscriber=1;tmi-sent-ts=1234567890123;turbo=0;user-id=44444;user-type= '
    ':escapetest!escapetest@escapetest.tmi.twitch.tv PRIVMSG #channel :test message';

/// A CLEARCHAT command that bans/times out a specific user
const clearChatUser =
    '@ban-duration=600;room-id=12345;target-user-id=67890;tmi-sent-ts=1234567890123 '
    ':tmi.twitch.tv CLEARCHAT #channel :banneduser';

/// A CLEARCHAT command that clears the entire chat (no target user)
const clearChatAll =
    '@room-id=12345;tmi-sent-ts=1234567890123 '
    ':tmi.twitch.tv CLEARCHAT #channel';

/// A CLEARMSG command that deletes a specific message
const clearMsg =
    '@login=deleteduser;room-id=;target-msg-id=target-msg-abc123;'
    'tmi-sent-ts=1234567890123 '
    ':tmi.twitch.tv CLEARMSG #channel :deleted message content';

/// A NOTICE command (system message)
const noticeMessage =
    '@msg-id=slow_on;room-id=12345 '
    ':tmi.twitch.tv NOTICE #channel :This room is now in slow mode.';

/// A USERNOTICE command (subscription, raid, etc.)
const userNoticeSubscription =
    '@badge-info=subscriber/1;badges=subscriber/0;color=#FF69B4;'
    'display-name=NewSub;emotes=;id=sub-123;login=newsub;mod=0;'
    'msg-id=sub;msg-param-cumulative-months=1;msg-param-months=0;'
    'msg-param-multimonth-duration=0;msg-param-multimonth-tenure=0;'
    'msg-param-should-share-streak=0;msg-param-sub-plan-name=Channel\\sSub;'
    'msg-param-sub-plan=1000;msg-param-was-gifted=false;room-id=12345;'
    'subscriber=1;system-msg=NewSub\\ssubscribed\\sat\\sTier\\s1.;'
    'tmi-sent-ts=1234567890123;user-id=55555;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// A ROOMSTATE command with room settings
const roomState =
    '@emote-only=0;followers-only=-1;r9k=0;room-id=12345;slow=0;subs-only=0 '
    ':tmi.twitch.tv ROOMSTATE #channel';

/// A USERSTATE command with user state info
const userState =
    '@badge-info=;badges=broadcaster/1;color=#FF0000;display-name=Broadcaster;'
    'emote-sets=0,300374282;mod=0;subscriber=0;user-type= '
    ':tmi.twitch.tv USERSTATE #channel';

/// A GLOBALUSERSTATE command
const globalUserState =
    '@badge-info=;badges=premium/1;color=#8A2BE2;display-name=GlobalUser;'
    'emote-sets=0,300374282;user-id=12345;user-type= '
    ':tmi.twitch.tv GLOBALUSERSTATE';

/// A message with Unicode that should be filtered (invalid Unicode char)
const messageWithInvalidUnicode =
    '@badge-info=;badges=;color=#00FF00;display-name=UnicodeTest;emotes=;'
    'id=unicode-123;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=66666;user-type= '
    ':unicodetest!unicodetest@unicodetest.tmi.twitch.tv PRIVMSG #channel '
    ':Hello\u{E0000}World';

/// A message that is a reply to another message
const replyMessage =
    '@badge-info=;badges=;color=#FF4500;display-name=Replier;emotes=;'
    'id=reply-123;mod=0;reply-parent-display-name=OriginalUser;'
    'reply-parent-msg-body=original\\smessage;reply-parent-msg-id=original-123;'
    'reply-parent-user-id=77777;reply-parent-user-login=originaluser;'
    'room-id=12345;subscriber=0;tmi-sent-ts=1234567890123;'
    'turbo=0;user-id=88888;user-type= '
    ':replier!replier@replier.tmi.twitch.tv PRIVMSG #channel :@OriginalUser this is my reply';

/// A message from a moderator
const moderatorMessage =
    '@badge-info=subscriber/24;badges=moderator/1,subscriber/24;'
    'color=#2E8B57;display-name=ModUser;emotes=;id=mod-123;mod=1;'
    'room-id=12345;subscriber=1;tmi-sent-ts=1234567890123;'
    'turbo=0;user-id=99999;user-type=mod '
    ':moduser!moduser@moduser.tmi.twitch.tv PRIVMSG #channel :Mod message here';

/// A message with no color set (should default to grey)
const messageNoColor =
    '@badge-info=;badges=;color=;display-name=NoColor;emotes=;'
    'id=nocolor-123;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=11111;user-type= '
    ':nocolor!nocolor@nocolor.tmi.twitch.tv PRIVMSG #channel :No color message';

/// A historical message (from recent messages API)
const historicalMessage =
    '@badge-info=;badges=;color=#FF0000;display-name=HistUser;emotes=;'
    'historical=1;id=hist-123;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=12121;user-type= '
    ':histuser!histuser@histuser.tmi.twitch.tv PRIVMSG #channel :Historical message';

/// A message from a shared chat session (source room different from current)
const sharedChatMessage =
    '@badge-info=;badges=;color=#00BFFF;display-name=SharedUser;emotes=;'
    'id=shared-123;mod=0;room-id=12345;source-room-id=99999;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=13131;user-type= '
    ':shareduser!shareduser@shareduser.tmi.twitch.tv PRIVMSG #channel :From another channel';

/// A message with emoji characters
const messageWithEmoji =
    '@badge-info=;badges=;color=#FFD700;display-name=EmojiUser;emotes=;'
    'id=emoji-123;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=14141;user-type= '
    ':emojiuser!emojiuser@emojiuser.tmi.twitch.tv PRIVMSG #channel :Hello 😀🎉 World';

/// A message with empty body (edge case)
const messageEmptyBody =
    '@badge-info=;badges=;color=#FF0000;display-name=EmptyMsg;emotes=;'
    'id=empty-123;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=16161;user-type= '
    ':emptymsg!emptymsg@emptymsg.tmi.twitch.tv PRIVMSG #channel :';

/// A message containing only emotes (no text words)
const messageOnlyEmotes =
    '@badge-info=;badges=;color=#FF0000;display-name=EmoteOnly;'
    'emotes=25:0-4,6-10;id=emoteonly-123;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=17171;user-type= '
    ':emoteonly!emoteonly@emoteonly.tmi.twitch.tv PRIVMSG #channel :Kappa Kappa';

/// A message with a URL
const messageWithUrl =
    '@badge-info=;badges=;color=#9400D3;display-name=LinkUser;emotes=;'
    'id=url-123;mod=0;room-id=12345;subscriber=0;'
    'tmi-sent-ts=1234567890123;turbo=0;user-id=15151;user-type= '
    ':linkuser!linkuser@linkuser.tmi.twitch.tv PRIVMSG #channel :Check out https://twitch.tv/channel';

/// A resub that shares its streak, with an emote in the user's message.
const resubStreak =
    '@badge-info=subscriber/14;badges=subscriber/12,premium/1;color=#1E90FF;'
    'display-name=ReSubber;emotes=25:0-4;id=resub-1;login=resubber;mod=0;'
    'msg-id=resub;msg-param-cumulative-months=14;msg-param-months=0;'
    'msg-param-should-share-streak=1;msg-param-streak-months=5;'
    'msg-param-sub-plan-name=Channel\\sSub;msg-param-sub-plan=1000;'
    'room-id=12345;subscriber=1;'
    "system-msg=ReSubber\\ssubscribed\\sat\\sTier\\s1.\\sThey've\\ssubscribed"
    '\\sfor\\s14\\smonths,\\scurrently\\son\\sa\\s5\\smonth\\sstreak!;'
    'tmi-sent-ts=1700000000001;user-id=20001;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel :Kappa 14 months!';

/// The same resub, from a viewer who chose to hide their streak.
const resubHiddenStreak =
    '@badge-info=subscriber/14;badges=subscriber/12,premium/1;color=#1E90FF;'
    'display-name=ReSubber;emotes=25:0-4;id=resub-1;login=resubber;mod=0;'
    'msg-id=resub;msg-param-cumulative-months=14;msg-param-months=0;'
    'msg-param-should-share-streak=0;msg-param-streak-months=5;'
    'msg-param-sub-plan-name=Channel\\sSub;msg-param-sub-plan=1000;'
    'room-id=12345;subscriber=1;'
    "system-msg=ReSubber\\ssubscribed\\sat\\sTier\\s1.\\sThey've\\ssubscribed"
    '\\sfor\\s14\\smonths!;'
    'tmi-sent-ts=1700000000001;user-id=20001;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel :Kappa 14 months!';

/// A first subscription paid with Prime.
const primeSub =
    '@badge-info=subscriber/1;badges=subscriber/0,premium/1;color=;'
    'display-name=PrimeUser;emotes=;id=prime-1;login=primeuser;mod=0;'
    'msg-id=sub;msg-param-cumulative-months=1;'
    'msg-param-should-share-streak=0;msg-param-sub-plan-name=Channel\\sSub;'
    'msg-param-sub-plan=Prime;room-id=12345;subscriber=1;'
    'system-msg=PrimeUser\\ssubscribed\\swith\\sPrime.;'
    'tmi-sent-ts=1700000000002;user-id=20002;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// One gifted sub, from a gifter who has given three in the channel.
const subGift =
    '@badge-info=;badges=premium/1;color=#00FF7F;display-name=Gifter;emotes=;'
    'id=gift-1;login=gifter;mod=0;msg-id=subgift;msg-param-gift-months=1;'
    'msg-param-months=2;msg-param-origin-id=da\\s39\\sa3\\see;'
    'msg-param-recipient-display-name=Lucky;msg-param-recipient-id=30001;'
    'msg-param-recipient-user-name=lucky;msg-param-sender-count=3;'
    'msg-param-sub-plan-name=Channel\\sSub;msg-param-sub-plan=1000;'
    'room-id=12345;subscriber=0;'
    'system-msg=Gifter\\sgifted\\sa\\sTier\\s1\\ssub\\sto\\sLucky!\\sThey\\shave'
    '\\sgiven\\s3\\sGift\\sSubs\\sin\\sthe\\schannel!;'
    'tmi-sent-ts=1700000000003;user-id=20003;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// A gift of three months of Tier 1, the gifter's first in the channel.
const multiMonthGift =
    '@badge-info=;badges=premium/1;color=#00FF7F;display-name=Gifter;emotes=;'
    'id=gift-3m;login=gifter;mod=0;msg-id=subgift;msg-param-gift-months=3;'
    'msg-param-months=2;msg-param-origin-id=aa\\sbb\\scc;'
    'msg-param-recipient-display-name=Lucky;msg-param-recipient-id=30001;'
    'msg-param-recipient-user-name=lucky;msg-param-sender-count=1;'
    'msg-param-sub-plan-name=Channel\\sSub;msg-param-sub-plan=1000;'
    'room-id=12345;subscriber=0;'
    'system-msg=Gifter\\sgifted\\s3\\smonths\\sof\\sTier\\s1\\sto\\sLucky.'
    "\\sIt's\\stheir\\sfirst\\sGift\\sSub\\sin\\sthe\\schannel!;"
    'tmi-sent-ts=1700000000004;user-id=20003;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// An anonymous gift, as modern IRC sends it: a `subgift` from Twitch's
/// anonymous gifter account.
const anonymousSubGift =
    '@badge-info=;badges=;color=;display-name=AnAnonymousGifter;emotes=;'
    'id=anon-gift-1;login=ananonymousgifter;mod=0;msg-id=subgift;'
    'msg-param-gift-months=1;msg-param-months=1;'
    'msg-param-origin-id=ab\\scd\\sef;'
    'msg-param-recipient-display-name=Lucky;msg-param-recipient-id=30001;'
    'msg-param-recipient-user-name=lucky;'
    'msg-param-sub-plan-name=Channel\\sSub;msg-param-sub-plan=1000;'
    'room-id=12345;subscriber=0;'
    'system-msg=An\\sanonymous\\suser\\sgifted\\sa\\sTier\\s1\\ssub\\sto'
    '\\sLucky!;'
    'tmi-sent-ts=1700000000005;user-id=274598607;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// The legacy form of an anonymous gift, with its own msg-id.
const anonymousSubGiftLegacy =
    '@badge-info=;badges=;color=;display-name=AnAnonymousGifter;emotes=;'
    'id=anon-gift-legacy;login=ananonymousgifter;mod=0;msg-id=anonsubgift;'
    'msg-param-months=1;msg-param-recipient-display-name=Lucky;'
    'msg-param-recipient-id=30001;msg-param-recipient-user-name=lucky;'
    'msg-param-sub-plan-name=Channel\\sSub;msg-param-sub-plan=1000;'
    'room-id=12345;subscriber=0;'
    'system-msg=An\\sanonymous\\suser\\sgifted\\sa\\sTier\\s1\\ssub\\sto'
    '\\sLucky!;'
    'tmi-sent-ts=1700000000006;user-id=274598607;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// The header of a five-sub gift bomb.
const massGiftHeader =
    '@badge-info=;badges=premium/1;color=#FF4500;display-name=BigGifter;'
    'emotes=;id=mystery-1;login=biggifter;mod=0;msg-id=submysterygift;'
    'msg-param-community-gift-id=1234567890123456789;'
    'msg-param-mass-gift-count=5;msg-param-origin-id=4e\\s29\\sab;'
    'msg-param-sender-count=50;msg-param-sub-plan=1000;room-id=12345;'
    'subscriber=0;'
    'system-msg=BigGifter\\sis\\sgifting\\s5\\sTier\\s1\\sSubs\\sto'
    "\\sChannel's\\scommunity!\\sThey've\\sgifted\\sa\\stotal\\sof\\s50\\sin"
    '\\sthe\\schannel!;'
    'tmi-sent-ts=1700000000100;user-id=20004;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// The same header, replayed from the recent-messages history.
const massGiftHeaderHistorical =
    '@badge-info=;badges=premium/1;color=#FF4500;display-name=BigGifter;'
    'emotes=;historical=1;id=mystery-1;login=biggifter;mod=0;'
    'msg-id=submysterygift;msg-param-community-gift-id=1234567890123456789;'
    'msg-param-mass-gift-count=5;msg-param-origin-id=4e\\s29\\sab;'
    'msg-param-sender-count=50;msg-param-sub-plan=1000;room-id=12345;'
    'subscriber=0;'
    'system-msg=BigGifter\\sis\\sgifting\\s5\\sTier\\s1\\sSubs\\sto'
    "\\sChannel's\\scommunity!\\sThey've\\sgifted\\sa\\stotal\\sof\\s50\\sin"
    '\\sthe\\schannel!;'
    'tmi-sent-ts=1700000000100;user-id=20004;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// The same header, relayed from another channel of a shared chat.
const massGiftHeaderShared =
    '@badge-info=;badges=premium/1;color=#FF4500;display-name=BigGifter;'
    'emotes=;id=mystery-1;login=biggifter;mod=0;msg-id=submysterygift;'
    'msg-param-community-gift-id=1234567890123456789;'
    'msg-param-mass-gift-count=5;msg-param-origin-id=4e\\s29\\sab;'
    'msg-param-sender-count=50;msg-param-sub-plan=1000;room-id=12345;'
    'source-room-id=99999;subscriber=0;'
    'system-msg=BigGifter\\sis\\sgifting\\s5\\sTier\\s1\\sSubs\\sto'
    "\\sChannel's\\scommunity!\\sThey've\\sgifted\\sa\\stotal\\sof\\s50\\sin"
    '\\sthe\\schannel!;'
    'tmi-sent-ts=1700000000100;user-id=20004;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// One gift of [massGiftHeader]'s bomb, to `Viewer$i` (i from 1 to 5).
String massGiftRecipient(int i) =>
    '@badge-info=;badges=premium/1;color=#FF4500;display-name=BigGifter;'
    'emotes=;id=mystery-1-r$i;login=biggifter;mod=0;msg-id=subgift;'
    'msg-param-community-gift-id=1234567890123456789;'
    'msg-param-gift-months=1;msg-param-months=1;'
    'msg-param-origin-id=4e\\s29\\sab;'
    'msg-param-recipient-display-name=Viewer$i;'
    'msg-param-recipient-id=4000$i;msg-param-recipient-user-name=viewer$i;'
    'msg-param-sender-count=0;msg-param-sub-plan-name=Channel\\sSub;'
    'msg-param-sub-plan=1000;room-id=12345;subscriber=0;'
    'system-msg=BigGifter\\sgifted\\sa\\sTier\\s1\\ssub\\sto\\sViewer$i!;'
    'tmi-sent-ts=170000000010$i;user-id=20004;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// The five gifts that follow [massGiftHeader].
final massGiftRecipients = [for (var i = 1; i <= 5; i++) massGiftRecipient(i)];

/// A five-sub gift bomb from an anonymous gifter.
const anonymousMassGift =
    '@badge-info=;badges=;color=;display-name=AnAnonymousGifter;emotes=;'
    'id=anon-mystery-1;login=ananonymousgifter;mod=0;msg-id=submysterygift;'
    'msg-param-community-gift-id=9876543210987654321;'
    'msg-param-mass-gift-count=5;msg-param-origin-id=9f\\s8e\\s7d;'
    'msg-param-sender-count=0;msg-param-sub-plan=1000;room-id=12345;'
    'subscriber=0;'
    'system-msg=An\\sanonymous\\suser\\sis\\sgifting\\s5\\sTier\\s1\\sSubs'
    "\\sto\\sChannel's\\scommunity!;"
    'tmi-sent-ts=1700000000150;user-id=274598607;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// A gifted sub continued by its recipient. Twitch's app drops this kind.
const giftPaidUpgrade =
    '@badge-info=subscriber/1;badges=subscriber/0;display-name=Upgrader;'
    'emotes=;id=upgrade-1;login=upgrader;mod=0;msg-id=giftpaidupgrade;'
    'msg-param-sender-login=gifter;msg-param-sender-name=Gifter;'
    'room-id=12345;subscriber=1;'
    'system-msg=Upgrader\\sis\\scontinuing\\sthe\\sGift\\sSub\\sthey\\sgot'
    '\\sfrom\\sGifter!;'
    'tmi-sent-ts=1700000000200;user-id=20005;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// A Tier 1 sub extended through June.
const extendSub =
    '@badge-info=subscriber/8;badges=subscriber/6;color=;'
    'display-name=Extender;emotes=;id=extend-1;login=extender;mod=0;'
    'msg-id=extendsub;msg-param-cumulative-months=8;'
    'msg-param-sub-benefit-end-month=6;msg-param-sub-plan=1000;'
    'room-id=12345;subscriber=1;'
    'system-msg=Extender\\sextended\\stheir\\sTier\\s1\\ssubscription'
    '\\sthrough\\sJune!;'
    'tmi-sent-ts=1700000000300;user-id=20006;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// A sub that counts towards the channel's sub goal.
const subWithGoal =
    '@badge-info=subscriber/1;badges=subscriber/0;color=;'
    'display-name=GoalSub;emotes=;id=goal-1;login=goalsub;mod=0;msg-id=sub;'
    'msg-param-cumulative-months=1;'
    'msg-param-goal-contribution-type=SUBS;'
    'msg-param-goal-current-contributions=524;'
    'msg-param-goal-description=Road\\sto\\s1200;'
    'msg-param-goal-target-contributions=1200;'
    'msg-param-goal-user-contributions=1;'
    'msg-param-should-share-streak=0;msg-param-sub-plan=1000;'
    'room-id=12345;subscriber=1;'
    'system-msg=GoalSub\\ssubscribed\\sat\\sTier\\s1.;'
    'tmi-sent-ts=1700000000400;user-id=20007;user-type= '
    ':tmi.twitch.tv USERNOTICE #channel';

/// A moderator deleting the message attached to [resubStreak].
const clearMsgResub =
    '@login=resubber;room-id=;target-msg-id=resub-1;'
    'tmi-sent-ts=1700000000500 '
    ':tmi.twitch.tv CLEARMSG #channel :Kappa 14 months!';

/// A moderator timing out the author of [resubStreak].
const clearChatResubber =
    '@ban-duration=600;room-id=12345;target-user-id=20001;'
    'tmi-sent-ts=1700000000600 '
    ':tmi.twitch.tv CLEARCHAT #channel :resubber';
