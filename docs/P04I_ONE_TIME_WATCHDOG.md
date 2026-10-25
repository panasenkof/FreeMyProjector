# P-04I — one-time trial HOME auto-rollback watchdog (specification only)

**Decision, 25.10.2026:** a trial HOME switch MAY use a **single-use, bounded 30-minute rollback timer**, which the user can explicitly cancel by pressing a confirmed action on the physical remote. For first pilot, prefer configurable 5–10 minute timer, with 30 minutes as requested option. **Not implemented; NO projector write code authorized.** Never arm on every ordinary projector boot.

## Safety properties

1. Gate on G0–G4 from [P-04F](P04F_ANDROID9_RECOVERY_GATES.md), including **independently tested recovery**; USB keyboard is NOT an emergency method by owner decision.
2. Store immutable baseline SHA256, exact build/user0, original stock HOME and a bounded journal of only our system changes **atomically before the first write**. Refuse if missing/invalid.
3. Use a **PC watchdog, running independently of the projector APK**, with persistent deadline and a distinct process/scheduled job, plus optionally device-side AlarmManager as secondary convenience only.
4. Timer starts **only at the moment of the separately authorized HOME trial**, and never renews automatically on boot. Do not restart timer silently after PC sleep/reboot. Before any action compare current HOME, original HOME and journal, and verify authorized ADB.
5. Confirmation UI: clearly say «Пульт работает — оставить новый HOME», require **intentional OK click from physical remote**, no implicit cancellation on generic app startup, touchless timeout, background update, or mere Bluetooth pairing report. Ideally require PC-side confirmed acknowledgement so the PC watchdog is durably disarmed.
6. If deadline expires without confirmed acknowledgement and device is reachable, attempt **only previously authorized exact-original HOME return**; then read actual HOME. Do not enable all packages or delete anything automatically.
7. If PC sleeps/loses network, ADB becomes unauthorized, projector is offline, firmware differs, HOME is ambiguous, Google launcher unavailable, or device user != 0: STOP unsafe writes and report «automatic recovery unverified/unavailable». **Never claim automatic recovery was completed.**
8. Android AlarmManager may wake an APK process during sleep but its alarms are canceled at restart; boot receiver may be delayed/disabled and HOME app may crash. An APK-only 30-minute timer **is not a dependable rescue system**. See https://developer.android.com/reference/android/app/AlarmManager and https://developer.android.com/develop/background-work/services/alarms.

## Mandatory mock tests before any device pilot

- confirmed trial -> cancellation before deadline; no writes
- no confirmation -> deadline -> exact original HOME restored in fake ADB, verified by follow-up read
- confirmation after expiry -> cannot silently suppress an in-progress recovery
- restart PC, sleep and process crash -> durable deadline correctly handled; no unsafe extended period
- disconnected/unauthorized ADB, multiple devices, different user/build, missing stock launcher, malformed journal/hash -> **STOP / no speculative writes**
- reboot projector during trial -> no timer re-arm without original persisted authorization
- PowerShell task aborted, watchdog killed, wrong clock -> fail closed without false success
- real remote input lost -> user cannot accidentally confirm, timeout remains
- double cancellation, repeated expiry -> idempotent and bounded actions

**Status:** concept and test contract only, not an operational rollback. We will not build a real-home-switch tool in this change. First finish P-04H pairing discovery, assess G1–G4 and test ordinary APK without changing factory HOME.
