# Design

Port the Android 8–10 branch and `signedIn(keys)` method from upstream commit `6209fca8e` in isolation, without replacing the entire upstream `Adb.java` because this fork uses an older `Ui.tr` contract. Preserve `com.fader.freemyprojector`, private signing and P-04 feature gate. Signed-only retry does not issue shell commands and closes failed connection sockets. Device-specific optical buttons, Xiaomi protected packages and firmware extraction are **research only** until exact components are confirmed on the real device. See `docs/PROJECTOR_FUNCTIONS.md`.
