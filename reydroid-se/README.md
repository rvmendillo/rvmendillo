# ReyDroid SE

Custom iOS APK launcher and local Android emulator using the ARM64 threaded
interpreter from **UTM SE 4.7.5**. This is a new SwiftUI app, not a renamed Husk
IPA. It uses existing open-source CPU emulation and Android system components.

**Experimental.** Building and checking the IPA does not establish that Android
boots successfully or performs acceptably on a particular physical iPhone.
No physical-device Android boot or APK execution test has been completed.

## Use

1. Sign the unsigned IPA using your normal sideloading tool and install it.
2. Tap **Prepare Android**. The pinned system image is a 2.06 GB download.
   Allow at least 8 GB free space. Keep the app open; Pause/Resume is available.
3. Tap **Start Android** and wait. Cold boot under CPU interpretation can take
   a long time; the Android screen and boot log show actual progress.
4. Import `.apk` files from Files. Once Android is ready, tap **Install**.
5. Installed apps appear in the grid. Tap one to launch it.

No JIT entitlement, development certificate, StikDebug, pairing file, remote
Android server, or jailbreak is required by this app. Ordinary iOS app signing
is still required. A standard signing service must re-sign embedded frameworks
as well as the main executable.

Android and its data remain on the phone. Only initial runtime download traffic
and networking initiated by Android apps leave the phone. The framebuffer uses
a private Unix socket. The guest shell port is random and bound to loopback.

## Limits

- Performance is far slower than JIT or hardware virtualization.
- ARM64 APKs are the target. 32-bit-only APKs and split `.apks`/`.xapk` bundles
  are not supported. No guarantee of Google Play Services, DRM, or game support.
- No audio, camera, native sensors, Play Store, or multi-touch in this prototype.
- Text injection supports basic Latin text; arbitrary Unicode needs more work.
- Android has 2 GB guest memory backed by a file. iOS may still terminate the
  app if memory or storage becomes tight.
- A stopped VM requires closing and reopening the iOS app for a new session.
- Imports stay in Files under ReyDroid SE/APKs; Android disks are under Android.
- Do not overwrite Android disks while the VM is running.

## Build

Requires macOS, Xcode, XcodeGen, Python 3.11+, and Swift.

```sh
python3 scripts/prepare_runtime.py
swift scripts/make_icon.swift App/Assets.xcassets/AppIcon.appiconset
swiftc App/FrameBuffer.swift App/Connection.swift Tests/main.swift -o /tmp/reydroid-tests
/tmp/reydroid-tests
xcodegen generate
xcodebuild -project ReyDroidSE.xcodeproj -scheme ReyDroidSE \
  -sdk iphoneos -configuration Release -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

The runtime preparation script pins and verifies both upstream downloads,
checks the actual TCTI interpreter symbols, selects only the ARM64 engine and
its transitive frameworks, and includes UEFI firmware and both Android disk
seeds. `tcg` in the launch arguments is the QEMU accelerator name; the pinned
SE binary executes its interpreter, rather than generating native code.

## Sources and licenses

ReyDroid SE source: GPL-2.0-or-later (see LICENSE).

- UTM 4.7.5 and its matching dependency build instructions, patches and source
  pins: https://github.com/utmapp/UTM/tree/v4.7.5
- QEMU interpreter source: https://github.com/utmapp/qemu
- Android image and its guest shell integration: https://github.com/Leviidev/Husk
  (pinned dependency `lineage-v2/vda-v12.qcow2`, verified by SHA-256 in the app).
- Guest disk templates, LineageOS device source/build instructions:
  https://github.com/jqssun/android-lineage-qemu/tree/v2026.09.17
- Android/LineageOS source: https://github.com/LineageOS

Upstream licenses and notices remain applicable. UTM's complete dependency
license acknowledgements and EDK2 license file are included in the app resources.
The project reuses the published SE libraries without binary modification.
