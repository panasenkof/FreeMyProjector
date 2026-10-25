# Instructions for AI agents — FreeMyProjector

This repository is an **independent MIT-licensed adaptation** of [Free My TV](https://github.com/simbasjungles/free-my-tv) for a Xiaomi Mi Smart Compact Projector (**system-reported MiProjM05**, Android 9, build `PQ3B.190705.003.4185`; retail SKU MJJGTYDS02FM not confirmed). Treat `UPSTREAM.md` as provenance.

## Sources of truth
1. `PLAN.md` — canonical priorities, status and pending user confirmations.
2. `docs/SDD_GUIDE.md` — how to author and review requirements.
3. `openspec/changes/<change-name>/` — *proposed*, not-yet-verified behavior.
4. `openspec/specs/<capability>/spec.md` — only confirmed implemented behavior.
5. `docs/PROJECTOR_COMPATIBILITY.md` — hardware hypotheses, diagnostics and manual tests.

Keep upstream `CLAUDE.md` for historical guidance, **but do not follow its model-specific install / system modification steps without separate safety review**. When it conflicts with these instructions, apply this project's safety constraints.

## Mandatory process for behavioral changes
- Read the relevant existing code and the current change specs before proposing modifications.
- Each roadmap feature must have scoped `proposal.md`, verifiable delta `specs/.../spec.md`, `design.md` (when technical choices matter), and `tasks.md`.
- Separate expected behaviors from implementation mechanics; use OpenSpec headings `### Requirement:` and `#### Scenario:` and WHEN/THEN scenarios.
- Discuss unknown hardware/firmware behavior openly. Never invent successful hardware tests.
- Ask for owner review of user-visible behavior and any irreversible or system-changing action **before code is deployed to the projector**.
- Implementation PR must link the change docs, provide tests, CI outcomes, risk analysis, and brief manual-test instructions.
- Do not call a task verified until its acceptance evidence exists. After confirmation, sync specs and archive the change; update `PLAN.md`.
- Tiny wording-only documentation edits may use a short PR without a full set of SDD artifacts.

## Hard safety guardrails
- Prefer **read-only** diagnostics before any ADB, HOME, network, boot or package-manager changes.
- Never execute or recommend disabling, deleting or reconfiguring a Xiaomi system app, Wi-Fi, launcher or recovery without exact-firmware investigation, a documented rollback and the owner's explicit go-ahead.
- No root by default; no bypassing safety measures to make switching HOME work.
- Backward-compatible, recoverable updates are mandatory. Preserving access to the factory home screen is a P0 requirement.
- **ADR-001 (P0):** [обратимая замена HOME через пользовательский APK](docs/ADR-001-REVERSIBLE-LAUNCHER.md) — обязательна для всех изменений. Наш APK должен безопасно устанавливаться/обновляться/удаляться; штатный Launcher и все OEM-компоненты остаются активными. Никаких root, перепрошивки или отключения заводского HOME; тестирование на устройстве и независимый путь отката обязательны до HOME-пилота.
- Keep privacy and secrets out of Git, logs and PRs: no API keys, private tokens, keystores, device serials, MAC addresses or user network addresses.
- This is initially Android TV / Android 9; keep the existing Java, no-Gradle `build.sh` build unless the spec justifies changing it.
- P-03 identity: manifest app ID `com.fader.freemyprojector`, original Java package `io.freemytv` (absolute component class names), release signing only with private owner-controlled PKCS12 credentials. **Do not reintroduce hard-coded signing keys or passwords**. Ordinary PR builds remain unsigned and use no release secrets. See [docs/RELEASE_SIGNING.md](docs/RELEASE_SIGNING.md).
- P-04 is not audited: `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED` MUST remain `false`, and ADB-backed jobs must remain gated until the exact Xiaomi firmware's rollback mechanism is reviewed and explicitly approved. A successful P-03 build does not authorize activating HOME mode.
- YouTube network performance is independent of home launcher replacement; diagnose before recommending changes. Never claim a VPN/proxy improves performance without local evidence.
- Preserve original MIT license and author notice for reused code.

## Review checklist
Check: spec ↔ code ↔ tests traceability; no risky ADB side effects; accidental secret leakage; Android 9 compatibility; handling HOME/BACK/remote; regression/rollback; actual vs assumed test results; updated canonical roadmap.

## Communication
Explain user-facing steps in plain Russian. Ask the user to confirm only important behavioral trade-offs and real-device checks; do not require them to write code or know SDD terminology.
