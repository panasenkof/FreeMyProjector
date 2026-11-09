# Upstream provenance

Original project: https://github.com/simbasjungles/free-my-tv

Imported upstream commit: `62e883b3179c8cafb7a2b09960eabfe7eea6ef1c`

License: MIT. Keep the upstream LICENSE and attribution when
distributing copies or substantial portions of the software.

This repository is an independent adaptation for Xiaomi Mi Smart Compact
Projector (reported model MJJGTYDS02FM). Upstream changes are optional
and should be reviewed before applying.

## Review on 2026-11-09 (selective sync, no HOME changes)

- Upstream Free My TV `main` [`ed6be1ecaa98`](https://github.com/simbasjungles/free-my-tv/commit/ed6be1ecaa98804c383fa021cdb648fd80f061f3) (07.11): **357** commits after the last reviewed `57ea4605`.
- Independent CleanYourTV `main` [`294d3d59d`](https://github.com/Gathin23/cleanyourtv/commit/294d3d59d) (08.11): **3085** commits after `575d73f0`. Its MiProjM05 tests use firmware `.2102` and `.1912`, not our `.4185`.
- Selected transfer: **five RU streaming shelf entries only** (installed apps are shown; no external ADB writes). Android 8/9 HOME fallback and remote helper updates were evaluated and **not** ported because our exact-home P0 guard and no-key-hook policy are safer for this projector.
- Detailed decisions, deferrals, tests and source links: [docs/UPSTREAM_REVIEW_2026-11-09.md](docs/UPSTREAM_REVIEW_2026-11-09.md).
- The imported baseline commit remains `62e883b3179c8cafb7a2b09960eabfe7eea6ef1c`; this review is **not** a full upstream merge and does not verify Xiaomi hardware.

## Review on 2026-10-25 (upstream and independent MiProjM05 project)

- Free My TV main [`57ea46051fc9`](https://github.com/simbasjungles/free-my-tv/commit/57ea46051fc9dc3201da425f858ef2768f1cc1f2) / [v1.2.0](https://github.com/simbasjungles/free-my-tv/releases/tag/v1.2.0): **54 more commits** since 24.10 review, **235 since original import**. Android 12 screensaver, MIUI TV HDMI (not this Amlogic Fengmi), regional RU shelf apps, sleep timer; **not merged wholesale**.
- Independent CleanYourTV main [`575d73f0f30c`](https://github.com/Gathin23/cleanyourtv/commit/575d73f0f30c329aa7ebaea2bc863943fd9bf7f9): **408 commits** since 24.10 review; MiProjM05 profile for firmware `.2102` remains distinct from our `.4185`.
- Relevant new CleanYourTV recovery learnings: explicit `--user 0` scoping (`7872bf0d2c`) and rejecting Android's HOME chooser (`92aa4aa302`). P-04D offline mock and P-04A passive OEM alias preflight are **our own constrained implementations**, not copied vendor code. See [research](docs/UPSTREAM_REVIEW_2026-10-25.md).
- Do not rewrite `Imported upstream commit`: it identifies code actually imported, not the most recent reviewed revision. Preserve license and P-04 HOME lock.

## Review on 2026-10-24 (partial port, not upstream merge)

- Imported original baseline: `62e883b3179c8cafb7a2b09960eabfe7eea6ef1c`.
- Upstream main reviewed: `aa34335d25fa2224053d1bb16851e4522a6bbeb0` — **181 commits after baseline**.
- Ported **only** `6209fca8e` (#221), Android 8–10 ADB authorization retry, to `app/src/io/freemytv/Adb.java`. Preserved this fork's older Ui API.
- Remaining changes **not** imported: Xiaomi TV remote keys, HY300 projector shortcuts (wrong device model), Android 8–12 glass, scrollable app shelf, internationalization, photo features, webOS/Tizen.
- Never overwrite Android app ID `com.fader.freemyprojector`, signing policy, or `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED = false`.
- Upstream baseline intentionally remains pinned to the actually imported `62e883b`, until a full tested sync.
- Relevant upstream references: https://github.com/simbasjungles/free-my-tv/commit/6209fca8e28679f868f473a8bdfd591028cf57a6 and https://github.com/simbasjungles/free-my-tv/commit/fb10f1a6325f9ffe502e31c60c4d695cad4d79c9 .
