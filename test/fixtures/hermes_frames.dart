// Hermes frames as observed on 2026-10-13 (anonymous, public web Client-ID).
// Session ids, message ids and the recovery token are placeholders.

const hermesWelcome =
    '{"type":"welcome","id":"msg-welcome","timestamp":"2026-10-13T15:50:01.123Z",'
    '"welcome":{"keepaliveSec":15,'
    '"recoveryUrl":"wss://hermes.twitch.tv/a/v1?clientId=CLIENT&t=TOKEN",'
    '"sessionId":"session-1"}}';

const hermesKeepalive =
    '{"type":"keepalive","id":"msg-ka","timestamp":"2026-10-13T15:50:11.000Z"}';

const hermesSubscribeOk =
    '{"type":"subscribeResponse","id":"msg-sr","parentId":"msg-sub-1",'
    '"timestamp":"2026-10-13T15:50:01.223Z",'
    '"subscribeResponse":{"subscription":{"id":"sub-1"},"result":"ok"}}';

const hermesSubscribeError =
    '{"type":"subscribeResponse","id":"msg-se","parentId":"msg-sub-2",'
    '"timestamp":"2026-10-13T15:50:01.300Z",'
    '"subscribeResponse":{"subscription":{"id":"sub-2"},"result":"error",'
    '"error":"invalid topic","errorCode":"SUB002"}}';

const hermesUnsubscribeOk =
    '{"type":"unsubscribeResponse","id":"msg-ur","parentId":"msg-unsub-1",'
    '"timestamp":"2026-10-13T15:51:00.000Z",'
    '"unsubscribeResponse":{"subscription":{"id":"sub-1"},"result":"ok"}}';

/// The pubsub payload is a JSON string inside the frame (double-encoded).
const hermesNotification =
    '{"type":"notification","id":"n-1-msg0-topic1sub-1",'
    '"timestamp":"2026-10-13T15:50:27.500Z",'
    '"notification":{"subscription":{"id":"sub-1"},"type":"pubsub",'
    r'"pubsub":"{\"type\":\"hype-train-progression\",\"data\":{\"sequence_id\":1540}}"}}';

const hermesReconnect =
    '{"type":"reconnect","id":"msg-rc","timestamp":"2026-10-13T15:55:00.000Z",'
    '"reconnect":{"url":"wss://hermes.twitch.tv/b/v1?clientId=CLIENT"}}';
