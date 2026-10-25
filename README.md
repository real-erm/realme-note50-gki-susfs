# Realme Note 50 GKI 2.0 Kernel Builder with SUSFS & Enforcing SELinux

Automated GitHub Actions CI/CD repository for compiling custom **Android Generic Kernel Image (GKI 2.0)** kernels for the **Realme Note 50 (UMS9230 / Unisoc Tiger T612, RMX3834)** with **KernelSU / KernelSU-Next** and **SUSFS (Stack-Unaware File System)** while maintaining **Strict SELinux Enforcement**.

---

## 📱 Device & Architecture Specifications

Even though Realme does not publish the device-specific kernel source code for the Realme Note 50, Android's **GKI 2.0 (Generic Kernel Image)** architecture isolates the core Linux kernel from vendor-specific drivers:

- **Device**: Realme Note 50 (`RMX3834`, `ums9230_1h10`)
- **Chipset**: Unisoc Tiger T612 (UMS9230)
- **Architecture**: `arm64` (aarch64), 4KB page size
- **Kernel Family**: Android 13 Linux LTS `5.15` (Stock snapshot: `5.15.178-android13-8-g0ff3dab2ed1b-ab36`)
- **GKI Version**: GKI 2.0 (Boot image header version 4)
- **Boot Partition Role**: The `boot` partition contains solely the generic Linux kernel `Image` (0 ramdisk). First-stage init ramdisk resides in `init_boot`, and vendor hardware drivers/modules reside in `vendor_boot`.

Because the `boot` partition contains pure upstream GKI code, we compile directly from the official **Google Android Common Kernel (ACK)** repository and flash the resulting kernel cleanly without breaking vendor hardware drivers, cameras, cellular baseband, or display!

---

## 🛡️ Features & Stealth Capabilities

### 1. Properly Enforced SELinux
- **Strictly Enforcing**: SELinux is compiled with `CONFIG_SECURITY_SELINUX=y` and `CONFIG_DEFAULT_SECURITY_SELINUX=y`. The kernel does **not** run in permissive mode (`permissive=0`, `enforcing=1`).
- **SELinux Status Spoofing**: SUSFS hooks `/sys/fs/selinux/status` so that non-root applications (UID ≥ 10000) always see `enforcing=1` with untouched security context attributes.
- **AVC Denial Spoofing**: Suppresses and spoofs audit vector log entries in `security/selinux/avc.c` so apps inspecting `dmesg` or logcat do not detect root activity.

### 2. SUSFS (Stack-Unaware File System)
- **Path & Mount Concealment**: Hides KernelSU overlay mounts, bind mounts, and root binaries from `/proc/mounts`, `/proc/[pid]/mountinfo`, and filesystem scans.
- **Symbol Cloaking**: Removes and masks KernelSU and SUSFS identifiers from `/proc/kallsyms`.
- **Command-line Concealment**: Spoofs `/proc/cmdline` and `/proc/bootconfig` to prevent bootloader unlock detection.
- **Open Redirection**: Safely redirects file operations away from protected locations.

### 3. Stock Config Spoofing (`/proc/config.gz`)
- Embeds the genuine stock Realme Note 50 defconfig extracted from the device's firmware snapshot into the kernel binary (`config/stock_defconfig`).
- Banking apps and integrity checkers that decompress `/proc/config.gz` see the clean, unmodified stock Google GKI configuration without root or custom kernel flags.

### 4. Clean Build Banner
- Strips the `-dirty` suffix from `setlocalversion`.
- Spoofs compile host and user to `build-user@build-host` to match OEM stock release banners.

---

## 🚀 How to Build via GitHub Actions

1. Fork or push this repository to your GitHub account.
2. In your repository on GitHub, navigate to the **Actions** tab.
3. Select **Build Realme Note 50 GKI 2.0 (SUSFS + SELinux Enforcing)** from the workflow list on the left.
4. Click **Run workflow**:
   - **Android Common Kernel Tag or Branch**: `android13-5.15.178_r00` (or `android13-5.15`)
   - **Android Version**: `android13`
   - **Kernel Version**: `5.15`
   - **Root Provider**: `KernelSU` (or `KernelSU-Next`)
   - **Enable SUSFS**: `true`
   - **Spoof /proc/config.gz**: `true`
   - **Create GitHub Release**: `true`
5. Click the green **Run workflow** button.
6. The build takes approximately 30–45 minutes. Once finished:
   - Check the **Releases** page or the **Artifacts** section of the run.
   - Download the generated ZIP containing `boot.img`, `AnyKernel3-*.zip`, `Image`, and `susfs4ksu-module.zip`.

---

## ⚡ Flashing Instructions

### Method 1: Fastboot Boot Image Flash (Recommended)

1. Put your Realme Note 50 into Fastboot mode:
   - Power off the phone.
   - Hold **Volume Down + Power** until the fastboot screen appears (or run `adb reboot bootloader`).
2. Connect the phone to your PC via USB.
3. Verify fastboot communication:
   ```bash
   fastboot devices
   ```
4. Flash the custom `boot.img` directly to the boot partition:
   ```bash
   # Flash active slot (or flash directly to boot)
   fastboot flash boot boot.img
   
   # Or flash slot explicitly if needed:
   fastboot flash boot_a boot.img
   fastboot flash boot_b boot.img
   ```
5. *(Optional / AVB disabled devices)*: If your device requires AVB verification disabled before running modified boot images:
   ```bash
   fastboot --disable-verity --disable-verification flash vbmeta vbmeta_a.img
   ```
6. Reboot your device:
   ```bash
   fastboot reboot
   ```

---

### Method 2: AnyKernel3 Recovery Flash

If your device has a working custom recovery (e.g. TWRP or OrangeFox):
1. Copy `AnyKernel3-Realme-Note50-GKI2.0-SUSFS.zip` to your internal storage or SD card.
2. Reboot into recovery.
3. Flash the zip file. AnyKernel3 will automatically split the boot image, replace the GKI kernel `Image`, and write it back.
4. Reboot system.

---

## 🔧 Post-Installation Setup

1. **Install Root Manager**:
   - If built with KernelSU: Install the official [KernelSU Manager APK](https://github.com/tiann/KernelSU/releases).
   - If built with KernelSU-Next: Install the [KernelSU-Next Manager APK](https://github.com/KernelSU-Next/KernelSU-Next/releases).
2. **Install SUSFS Companion Module**:
   - Open KernelSU Manager.
   - Go to **Modules** -> **Install from file**.
   - Select `susfs4ksu-module.zip` (included in your build release artifacts).
   - Reboot your phone.
3. **Verify SUSFS Status**:
   In Termux or an `adb shell` with root (`su`):
   ```bash
   ksu_susfs susfs_show_version
   ```
   You should see the active SUSFS kernel version!
4. **Verify SELinux Status**:
   ```bash
   getenforce
   ```
   It will output:
   ```
   Enforcing
   ```

---

## 📂 Repository Layout

```
.
├── .github/
│   └── workflows/
│       └── build-kernel.yml      # Automated GitHub Actions GKI build workflow
├── config/
│   └── stock_defconfig           # Extracted genuine Realme Note 50 stock config
├── tools/
│   ├── AnyKernel3/               # GKI 2.0 AnyKernel3 flashable packaging template
│   └── mkbootimg/                # Android boot image header v4 tools
└── README.md                     # Documentation and flashing guide
```

---

## ⚠️ Recovery / Fallback

If you encounter any boot issue or want to revert to stock:
- Flash your stock `boot_a.img` from the backup archive:
  ```bash
  fastboot flash boot_a boot_a.img
  fastboot reboot
  ```

---

## 📜 Credits & Acknowledgments
- **Google Android Open Source Project (AOSP)**: Android Common Kernel (ACK) & GKI 2.0
- **KernelSU**: [tiann/KernelSU](https://github.com/tiann/KernelSU) & [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)
- **SUSFS**: [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
- **AnyKernel3**: [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3)
