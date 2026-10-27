# Realme Note 50 GKI 2.0 Kernel Builder with SUSFS & Enforcing SELinux

Automated GitHub Actions CI/CD repository for compiling custom **Android Generic Kernel Image (GKI 2.0)** kernels for the **Realme Note 50 (UMS9230 / Unisoc Tiger T612, RMX3834)** with **SukiSU-Ultra (Spoofed Variant)** / **KernelSU** and **SUSFS (Stack-Unaware File System)** while maintaining **Strict SELinux Enforcement**.

---

## 📱 Device & Architecture Specifications

Even though Realme does not publish device-specific kernel sources for the Realme Note 50, Android's **GKI 2.0 (Generic Kernel Image)** architecture isolates the core Linux kernel from vendor-specific drivers:

- **Device**: Realme Note 50 (`RMX3834`, `ums9230_1h10`)
- **Chipset**: Unisoc Tiger T612 (UMS9230)
- **Architecture**: `arm64` (aarch64), 4KB page size
- **Kernel Family**: Android 13 Linux LTS `5.15` (Stock snapshot: `5.15.178-android13-8-g0ff3dab2ed1b-ab36`)
- **GKI Version**: GKI 2.0 (Boot image header version 4)
- **Boot Partition Role**: The `boot` partition contains solely the generic Linux kernel `Image` (0 ramdisk). First-stage init ramdisk resides in `init_boot`, and vendor hardware drivers/modules reside in `vendor_boot`.

Because the `boot` partition contains pure upstream GKI code, we compile directly from the official **Google Android Common Kernel (ACK)** repository and flash the resulting kernel cleanly without breaking vendor hardware drivers, cameras, cellular baseband, or display!

---

## 🛡️ Features & Stealth Capabilities

### 1. SukiSU-Ultra (Spoofed Variant)
- **Randomized Package Identity**: Works with SukiSU-Ultra's spoofed manager build. The APK uses randomized package, activity, and service identifiers to evade package name-based root detection.
- **Dynamic Signature Fallback**: The kernel validates the APK's cryptographic v2 signature directly via `ksu_sig_fallback_run`, granting root access regardless of the randomized package name.
- **Full SUSFS Integration**: Native SUSFS controls built into the SukiSU-Ultra manager and `ksud` daemon.

### 2. Properly Enforced SELinux
- **Strictly Enforcing**: SELinux is compiled with `CONFIG_SECURITY_SELINUX=y` and `CONFIG_DEFAULT_SECURITY_SELINUX=y`. The kernel does **not** run in permissive mode (`permissive=0`, `enforcing=1`).
- **SELinux Status Spoofing**: SUSFS hooks `/sys/fs/selinux/status` so that non-root applications (UID ≥ 10000) always see `enforcing=1` with untouched security context attributes.
- **AVC Denial Spoofing**: Suppresses and spoofs audit vector log entries in `security/selinux/avc.c` so apps inspecting `dmesg` or logcat do not detect root activity.

### 3. SUSFS (Stack-Unaware File System)
- **Path & Mount Concealment**: Hides root overlay mounts, bind mounts, and root binaries from `/proc/mounts`, `/proc/[pid]/mountinfo`, and filesystem scans.
- **Symbol Cloaking**: Removes and masks KernelSU and SUSFS identifiers from `/proc/kallsyms`.
- **Command-line Concealment**: Spoofs `/proc/cmdline` and `/proc/bootconfig` to prevent bootloader unlock detection.
- **Open Redirection & Map Hiding**: Safely redirects file operations away from protected locations and hides mmapped files.

### 4. Stock Config Spoofing (`/proc/config.gz`)
- Embeds the genuine stock Realme Note 50 defconfig extracted from the device's firmware snapshot into the kernel binary (`config/stock_defconfig`).
- Banking apps and integrity checkers that decompress `/proc/config.gz` see the clean, unmodified stock Google GKI configuration without root or custom kernel flags.

### 5. Clean Build Banner
- Strips the `-dirty` suffix from `setlocalversion`.
- Spoofs compile host and user to `build-user@build-host` to match OEM stock release banners.

### 6. Doze Mode & Suspend Stability Fix (Unisoc Tiger T612 / UMS9230)
- **Hierarchical PSCI CPU Idle Domains**: Enables `CONFIG_ARM_PSCI_CPUIDLE_DOMAIN=y`, `CONFIG_DT_IDLE_STATES=y`, `CONFIG_CPU_IDLE_MULTIPLE_DRIVERS=y`, and `CONFIG_PM_GENERIC_DOMAINS_SLEEP=y`. Properly coordinates power collapse across the asymmetric big.LITTLE clusters (2x A75 + 6x A55) via PSCI firmware, preventing SoC sleep desynchronization.
- **Watchdog-Safe Suspend**: Sets `CONFIG_SUSPEND_SKIP_SYNC=y` to prevent lengthy storage filesystem syncs during sleep entry from tripping the Unisoc hardware PMIC watchdog timer.
- **Custom ROM & GSI SELinux Domain Compatibility**: Injects permissive `magisk` and `su` domains into the active kernel policy (`rules.c`) to ensure GSI init property actions (such as `sys.oem_unlock_allowed` toggles during idle maintenance) execute cleanly without `cannot setexeccon` fatal aborts.

---

## 🚀 How to Build via GitHub Actions

1. In this repository on GitHub, navigate to the **Actions** tab.
2. Select **Build Realme Note 50 GKI 2.0 (SUSFS + SELinux Enforcing)** from the workflow list on the left.
3. Click **Run workflow**:
   - **Android Common Kernel Tag or Branch**: `android13-5.15.178_r00` (or `android13-5.15`)
   - **Android Version**: `android13`
   - **Kernel Version**: `5.15`
   - **Root Provider**: `SukiSU-Ultra` (or `KernelSU`, `KernelSU-Next`)
   - **Enable SUSFS**: `true`
   - **Spoof /proc/config.gz**: `true`
   - **Create GitHub Release**: `true`
4. Click the green **Run workflow** button.
5. The build runs on GitHub Actions runners (saving local CPU & RAM resources). Once finished:
   - Check the **Releases** page or the **Artifacts** section of the run.
   - Download the generated `boot.img`, raw `Image`, `susfs4ksu-module.zip`, and matching **Spoofed Manager APK**.

---

## ⚡ Flashing Instructions (Fastbootd)

> [!IMPORTANT]
> **Use fastbootd (`adb reboot fastboot`) — NOT bootloader fastboot (`reboot bootloader`)**:
> The Realme Note 50 (Unisoc T612) dynamic partition scheme requires userspace fastboot (`fastbootd`) to flash GKI kernel boot images properly.
> 
> **AVB (Android Verified Boot)**:
> The exploit used to unlock the Realme Note 50 bootloader already bypasses and handles AVB automatically. You do **not** need to flash `vbmeta` or use `--disable-verity` flags.

1. Connect the phone to your PC via USB with USB debugging enabled.
2. Reboot into **fastbootd** (userspace fastboot):
   ```bash
   adb reboot fastboot
   ```
3. Once the screen shows the fastbootd menu, verify communication:
   ```bash
   fastboot devices
   ```
4. Flash the custom `boot.img` directly to the boot partition:
   ```bash
   # Flash directly to boot partition
   fastboot flash boot boot.img
   
   # Or flash slot explicitly if needed:
   fastboot flash boot_a boot.img
   fastboot flash boot_b boot.img
   ```
5. Reboot your device:
   ```bash
   fastboot reboot
   ```

---

## 🔧 Post-Installation Setup

1. **Install Spoofed Manager**:
   - Install the spoofed manager APK bundled in the release (`SukiSU_v4.2.1-r2_41068-release-spoofed.apk`).
   - The app installs with a randomized package name to defeat detection. The kernel recognizes and crowns it automatically.
2. **Install SUSFS Companion Module**:
   - Open SukiSU Manager.
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
- **SukiSU-Ultra**: [SukiSU-Ultra/SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
- **KernelSU**: [tiann/KernelSU](https://github.com/tiann/KernelSU) & [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)
- **SUSFS**: [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
