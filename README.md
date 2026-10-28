# Realme Note 50 (`RMX3834`) GKI 2.0 Kernel — SukiSU-Ultra & SUSFS

Custom **Android GKI 2.0 (`5.15`)** kernel for the **Realme Note 50** (`RMX3834` / Unisoc T612), built automatically with GitHub Actions.

Includes **SukiSU-Ultra (Spoofed Build)** for root access and **SUSFS** for hiding root, mounts, and bootloader unlock status.

---

## 📦 What's in Every Release

Each release on the **Releases** page ships with:

1. **`boot-enforcing.img`** — Kernel in **SELinux Enforcing** mode *(Recommended for stock ROM & most GSIs)*.
2. **`boot-permissive.img`** — Kernel in **SELinux Permissive** mode *(Use if your custom GSI has broken SELinux policies; still reports `Enforcing` to regular user apps)*.
3. **`SukiSU_*_spoofed.apk`** — Root Manager app *(uses a randomized package name so other apps cannot scan for it)*.
4. **`susfs4ksu-module.zip`** — SUSFS companion module *(flash inside the SukiSU Manager app)*.
5. **`ksu_susfs_tools.zip`** — Standalone `ksu_susfs` command-line tools.

---

## ⚡ How to Flash

> [!IMPORTANT]
> - Always use **`adb reboot fastboot`** to enter **`fastbootd`**. Do **NOT** use `adb reboot bootloader`.
> - The Realme Note 50 unlock exploit already handles AVB. You do **not** need to flash `vbmeta` or disable verity.

1. Reboot your phone into **fastbootd**:
   ```bash
   adb reboot fastboot
   ```
2. Flash **either** the Enforcing **or** Permissive boot image:
   ```bash
   # Recommended (SELinux Enforcing):
   fastboot flash boot boot-enforcing.img

   # Or if your GSI needs SELinux Permissive:
   fastboot flash boot boot-permissive.img
   ```
3. Reboot back to Android:
   ```bash
   fastboot reboot
   ```

---

## 🔧 Setup After Flashing

1. Install **`SukiSU_*_spoofed.apk`** from the release.
2. Open the SukiSU app -> **Modules** -> **Install from file** -> select **`susfs4ksu-module.zip`**.
3. Reboot your phone.

---

## ✨ Key Features

- **Root & Mount Hiding (SUSFS)**: Filters root mounts from `/proc/self/mountinfo` without breaking `/proc` file access, hides KernelSU/SUSFS symbols from `/proc/kallsyms`, and spoofs `/proc/cmdline` & `/proc/bootconfig` to report `locked` / `green`.
- **Stock Config Spoofing**: `/proc/config.gz` reports the untouched stock Realme Note 50 config (`config/stock_defconfig`).
- **Clean Kernel Banner**: Matches the stock Realme Note 50 kernel version suffix (`-android13-8-g0ff3dab2ed1b-ab36`) and removes `-dirty` flags so all stock vendor modules (`vendor_boot`) load cleanly.
- **Doze & Deep Sleep Fix**: Includes Unisoc T612 (`CONFIG_ARCH_SPRD`) PSCI CPU idle domain configs so the phone does not reboot when entering deep sleep / Doze mode.

---

## ⚠️ Known Issues

1. **Momo 4.4.1 Crashes on Android 15 / 16 GSIs**:
   - **Fixed**: Momo's *"The environment is broken: Damaging behavior is detected"* error (caused by SukiSU's default `mount_hide` returning `-ENOENT` on `/proc/self/mountinfo`) is **fixed** in this kernel by letting SUSFS filter `mountinfo` cleanly.
   - **Android 15/16 Momo Bug**: On Android 15 and Android 16 ROMs, Momo 4.4.1 (released in 2022) crashes right after starting because Google renamed `solist` to `solist_head` inside `/apex/com.android.runtime/bin/linker64`, causing a null-pointer crash inside Momo's own `libmahoshojo.so`.
2. **Custom GSI Fix Modules (`realme_note_50_gsi_fixes`)**:
   - If you use a GSI fix module that mounts an overlay on `/system/product/overlay` or creates world-readable folders in `/dev` (such as `/dev/imsfix`), apps that use `AppZygote` can fail to start when **"Umount modules"** is turned on for them, because Zygote tries to reopen the unmounted overlay APK.
3. **Spoofing an Android 15 Fingerprint on an Android 16 GSI**:
   - If you run an Android 16 GSI (`ro.build.version.sdk=36`) with a Play Integrity Fix module that spoofs Realme Note 50's stock Android 15 fingerprint (`ro.build.version.release=15`), strict root detectors will flag the mismatch between Android 15 and SDK 36.

---

## 🛠️ How to Trigger a New Build on GitHub

1. Open the **Actions** tab on GitHub.
2. Select **Build Realme Note 50 GKI 2.0 (SUSFS + Enforcing & Permissive)**.
3. Click **Run workflow** -> **Run workflow**.

---

## 📜 Credits

- [Google Android Common Kernel (ACK)](https://android.googlesource.com/kernel/common)
- [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
- [SUSFS (`susfs4ksu`)](https://gitlab.com/simonpunk/susfs4ksu)
