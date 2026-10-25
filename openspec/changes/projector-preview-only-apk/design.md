# P-05 preview APK design

### Mandatory double gate

__BT__ModeJob.PROJECTOR_HOME_SWITCH_AUDITED=false__BT__ remains enforced. Additionally, the shipped APK manifest explicitly disables __BT__HomeActivity__BT__, __BT__HomeReceiver__BT__, and __BT__RemoteKeyService__BT__. This prevents the preview APK being a system HOME candidate or self-starting/stealing keys. __BT__SettingsActivity__BT__ still has the Android TV leanback launcher entry.

### Offline build evidence

__BT__tools/ci/verify_identity.py__BT__ checks source XML, version semantics, HOME lock, permissions and launch intent filters. After __BT__build.sh__BT__, __BT__aapt2 dump xmltree__BT__ creates an independent representation of the built artifact, and __BT__tools/ci/verify_trial_manifest.py__BT__ verifies compiled enabled states. Repeat both on the **signed APK before release upload**. Any mismatch aborts the release before publishing.

### Signing, rollback and hardware work

Reuse existing PKCS12 signing secrets; do not create new keys. Signed workflow is manual, main-only, prerelease with monotonic v0.1.1 tag. No GitHub workflow connects to projector. Owner can separately install APK as a normal app for the limited UX test, then remove it using standard Android TV Apps menu. Reboot/flash/launcher role assignment are out of scope. Document manual status check that original Google TV HOME still works before and after install.
