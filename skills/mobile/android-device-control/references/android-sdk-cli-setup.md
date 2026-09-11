# Minimal Android SDK CLI setup on Arch Linux

Use this when Android development only needs real-device builds and ADB, not Android Studio, emulators, system images, or the NDK.

## Validated layout

Install the official command-line tools under a user-owned SDK root:

```text
~/Android/Sdk/
  cmdline-tools/latest/
  platform-tools/
  platforms/android-35/
  build-tools/35.0.0/
```

Obtain the current Linux command-line-tools URL and SHA-256 from the official Android Studio download page. Verify the archive before extraction. The zip contains a top-level `cmdline-tools` directory; place that directory at `~/Android/Sdk/cmdline-tools/latest`.

## Component installation

Recent command-line tools include the newer Android CLI. Prefer it over the deprecated `sdkmanager` after initializing it once:

```bash
~/Android/Sdk/cmdline-tools/latest/bin/android --sdk="$HOME/Android/Sdk" --no-metrics sdk install platform-tools
~/Android/Sdk/cmdline-tools/latest/bin/android --sdk="$HOME/Android/Sdk" --no-metrics sdk install 'platforms;android-35'
~/Android/Sdk/cmdline-tools/latest/bin/android --sdk="$HOME/Android/Sdk" --no-metrics sdk install 'build-tools;35.0.0'
```

Install only the packages the project needs. A physical-device Bluetooth gateway does not require Android Studio, an emulator, a system image, or the NDK.

If license acceptance is required, make it explicit as part of the user's SDK installation request. With legacy `sdkmanager --licenses`, do not combine `set -o pipefail`, `yes | ...`, and subsequent installs in one `&&` chain: `yes` can receive SIGPIPE after the license tool finishes, giving the pipeline status 141 and skipping otherwise-valid installation steps. Run license acceptance separately, verify files under `licenses/`, then run component installation as a separate command.

If `sdkmanager` downloads a corrupt archive and fails while unzipping, remove only its SDK temporary/partial target and retry with the newer `android sdk install` command. Capture this as a bounded retry, not a permanent claim that `sdkmanager` is broken.

## Persistent environment

For interactive zsh:

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/build-tools/35.0.0:$PATH"
```

For GUI/systemd user processes, put `ANDROID_HOME` and `ANDROID_SDK_ROOT` in `~/.config/environment.d/50-android-sdk.conf`. Do not assume that shell `PATH` is inherited by systemd user services.

## Verification

Verify installed-package inventory with:

```bash
android --sdk="$ANDROID_HOME" --no-metrics sdk list
```

Then verify real executables:

```bash
adb version
aapt2 version
d8 --version
```

Finally compile a tiny Java class that imports `android.bluetooth.BluetoothAdapter` and `android.bluetooth.BluetoothSocket` against:

```text
$ANDROID_HOME/platforms/android-35/android.jar
```

A successful `javac` compile proves the platform jar and Bluetooth API surface are usable; directory existence alone is not sufficient verification.
