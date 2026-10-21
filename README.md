# expo-dev-launcher: no loading state while a project opens

Opening a project in a development build by URL (scanning the dev server's QR code, a deep link,
or the launcher reopening the last project) shows **nothing** while the manifest is fetched and
the bundle is requested. On a slow or tunneled dev server that is many seconds, and the app looks
frozen or broken. On a cold start the screen is the launcher's server list, or the
previous project, until the new project suddenly replaces it.

The launcher already shows a spinner when you tap a server **inside** its own list
(`DevLauncherViewModel.isLoadingServer`). The URL path goes straight to
`EXDevLauncherController loadApp:` and never touches that view model.

## Reproduce

Blank SDK 58 app (`expo` 58.0.17, `expo-dev-launcher` 58.0.14, RN 0.88) with `expo-dev-client`.
Expo CLI evaluates `app.config.js` on every manifest request, and this one sleeps
`REPRO_DELAY_MS` when it is set, so a slow manifest is reproducible on any machine. In real
projects the same wait comes from the per-request `runtimeversion:resolve` (3-4.5s each under the
`fingerprint` policy on an SDK 55 app, asked twice per open), a tunnel, or a busy machine.

Once the manifest is in, React Native's own banner ("Loading from Metro…", "Bundling 49%")
covers the bundle phase. The manifest phase before it has no indicator at all.

```sh
npm install
npx expo prebuild -p ios
xcodebuild -workspace ios/devlauncherloadingrepro.xcworkspace -scheme devlauncherloadingrepro \
  -configuration Debug -sdk iphonesimulator -derivedDataPath ios/build
REPRO_DELAY_MS=4000 npx expo start --dev-client --port 8081
# then open, like a scanned QR code:
xcrun simctl openurl booted "exp+dev-launcher-loading-repro://expo-development-client/?url=http%3A%2F%2Flocalhost%3A8081"
```

`scripts/film-deeplink.sh` does the same on a given simulator and saves a screenshot every
~100ms from the moment the link opens.

**Expected:** some sign the project is loading, from the moment the link opens.
**Actual:** the launcher's home screen stays as it is until the bundle starts downloading.

## Fix

The `fix` branch applies the patch from
[simon-says-studio/expo#2](https://github.com/simon-says-studio/expo/pull/2) with patch-package.
