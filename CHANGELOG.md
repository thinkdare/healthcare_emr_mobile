# Changelog

Notable additions, changes and fixes, newest first.

## 2026-10-21

**Added**
- Local-first vital signs, the first slice of ADR 0001: writes go to SQLCipher and the outbox in one transaction, the UI reads only the local database, and a sync engine pushes and pulls (`8d7097b`).
- Fault-injection harness for the sync contract, with an in-memory fake server (`test/localfirst`).
- Opt-in live test that runs the real engine and Dio transport against a local backend (`0099e44`).

**Changed**
- Non-debug builds require `https://` base URLs and throw `StateError` at startup otherwise (`7cb94ea`).
- Login distinguishes a connection failure from an unknown account (`8442e26`).

**Fixed**
- The push loop spun forever when the server answered 200 without acknowledging any entry: the entries stayed pending and the same batch was re-sent at once. A round now stops when a batch makes no progress and reports `serverUnavailable`; the entries stay queued with their original bytes (`ef7ea5b`).

**Decisions**
- Rejections are per item inside a 200 response, and a rejected entry is dead-lettered on its own so it never blocks the queue. A reused id is rejected with `resource_id_already_exists` and the server row is never overwritten.
- No further module is converted to local-first until vitals passes the harness on a physical mid-range Android device.
