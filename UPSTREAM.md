# Upstream provenance

Original project: https://github.com/simbasjungles/free-my-tv

Imported upstream commit: `62e883b3179c8cafb7a2b09960eabfe7eea6ef1c`

License: MIT. Keep the upstream LICENSE and attribution when
distributing copies or substantial portions of the software.

This repository is an independent adaptation for Xiaomi Mi Smart Compact
Projector (reported model MJJGTYDS02FM). Upstream changes are optional
and should be reviewed before applying.

## Review on 2026-10-24 (partial port, not upstream merge)

- Imported original baseline: `62e883b3179c8cafb7a2b09960eabfe7eea6ef1c`.
- Upstream main reviewed: `aa34335d25fa2224053d1bb16851e4522a6bbeb0` — **181 commits after baseline**.
- Ported **only** `6209fca8e` (#221), Android 8–10 ADB authorization retry, to `app/src/io/freemytv/Adb.java`. Preserved this fork's older Ui API.
- Remaining changes **not** imported: Xiaomi TV remote keys, HY300 projector shortcuts (wrong device model), Android 8–12 glass, scrollable app shelf, internationalization, photo features, webOS/Tizen.
- Never overwrite Android app ID `com.fader.freemyprojector`, signing policy, or `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED = false`.
- Upstream baseline intentionally remains pinned to the actually imported `62e883b`, until a full tested sync.
- Relevant upstream references: https://github.com/simbasjungles/free-my-tv/commit/6209fca8e28679f868f473a8bdfd591028cf57a6 and https://github.com/simbasjungles/free-my-tv/commit/fb10f1a6325f9ffe502e31c60c4d695cad4d79c9 .
