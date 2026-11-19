
### First launch: allow the app once

This build isn't signed with an Apple Developer ID yet, so the first time you open it macOS says it can't verify the app. To open it anyway:

1. Open SuperDock once, and click **Done** on the warning.
2. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to "SuperDock was blocked…".
3. Confirm with **Open Anyway** and your password.

Or run this once in Terminal after dragging SuperDock into Applications:

```sh
xattr -dr com.apple.quarantine /Applications/SuperDock.app
```

You'll only need to do this once. Automatic updates aren't on in unsigned builds, so check the [Releases page](https://github.com/apurvamukherjee/SuperDoc/releases) for new versions.
