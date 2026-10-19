# Android location correction — version 1.1.1 (code 3)

- Let the native position call request permissions and resolve Android location settings. An unconditional requestPermissions call previously failed immediately when the system Location switch was off.
- Accept an existing approximate permission instead of requesting precise access again. Native GPS uses a 45-second initial timeout and retries a timed-out fix once with balanced accuracy.
- Read positions sequentially while the app is open. The Android plugin's error response releases a watch callback, so keeping a JavaScript sharing flag enabled did not ensure future callbacks. Foreground polling now retries temporary errors and stops on permission denial or explicit Stop sharing.
- Show actionable error instructions and preserve the native error code. Display progress while the initial fix is pending. Native operation does not depend on a browser HTTPS-context check.

Automated tests cover system Location off, approximate permission, timeout fallback, denial, transient polling recovery and cancellation. Test this release on the affected phone; no attached Android device is available in the build environment. Keep the app open. This update does not add background tracking.
