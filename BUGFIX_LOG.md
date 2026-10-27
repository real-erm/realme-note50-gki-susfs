# Realme Note 50 GKI 2.0 (SUSFS) — Static Audit & Bugfix Log

This document tracks bugs discovered and resolved in the `real-erm/realme-note50-gki-susfs` build pipeline, kernel configuration, and SUSFS packaging for the **Realme Note 50 (`RMX3834`, Unisoc Tiger T612 / `UMS9230`)**.

---

## 2026-10-28 — Static Audit & Pipeline Fixes

### 1. Fixed Broken `susfs4ksu-module.zip` Packaging (High)
- **Symptom**: Flashing `susfs4ksu-module.zip` in SukiSU / KernelSU Manager failed to install `/data/adb/ksu/bin/ksu_susfs`.
- **Root Cause**:
  1. `.github/workflows/build-kernel.yml` packaged the module with `zip -r ... ./* -x ".git*" "tools/*"`, stripping `tools/ksu_susfs_arm64` from the module zip even though `customize.sh` explicitly extracts and copies `tools/ksu_susfs_arm64` to `/data/adb/ksu/bin/ksu_susfs` during module installation.
  2. Using `./*` instead of `.` omitted the hidden dotfile `.susfs_no_auto_add_try_umount` in `ksu_module_susfs/`.
- **Fix**: Changed module packaging to `zip -r9 "${{ github.workspace }}/artifacts/susfs4ksu-module.zip" . -x ".git*"` so both `tools/ksu_susfs_arm64` and hidden dotfiles are preserved inside the module archive.

### 2. Added Missing `CONFIG_ARCH_SPRD=y` From Stock Defconfig (Medium)
- **Symptom**: Spreadtrum/Unisoc SoC platform flag `CONFIG_ARCH_SPRD` was disabled in compiled GKI builds.
- **Root Cause**: While `config/stock_defconfig` (extracted from Realme Note 50's stock `boot.img`) has `CONFIG_ARCH_SPRD=y`, upstream Google `gki_defconfig` only sets `CONFIG_SERIAL_SPRD=y` and leaves `CONFIG_ARCH_SPRD` unset.
- **Fix**: Explicitly injected `CONFIG_ARCH_SPRD=y` alongside the Unisoc Tiger T612 power management flags in `arch/arm64/configs/gki_defconfig`.

### 3. Fixed `.config` Verification Path & Added Strict Enforcement Assertions (Medium)
- **Symptom**: The `Verify Kernel Image and SELinux` step never executed its `.config` verification check.
- **Root Cause**: `build/build.sh` outputs the compiled configuration to `/home/runner/out/common/.config` (and `/home/runner/out/dist/.config`), whereas the workflow checked `/home/runner/out/.config`.
- **Fix**: Updated `CONFIG_PATH` to inspect `/home/runner/out/common/.config` (with fallback to `/home/runner/out/dist/.config`) and added a hard assertion that fails the CI run if `CONFIG_SECURITY_SELINUX=y` or `CONFIG_DEFAULT_SECURITY_SELINUX=y` is missing.

### 4. Completed Stock Kernel Banner Timestamp Spoofing (`UTS_VERSION`) (Medium)
- **Symptom**: While compile user/host (`build-user@build-host`) and vermagic (`-android13-8-g0ff3dab2ed1b-ab36`) matched the stock Realme Note 50 kernel, `uname -v` / `/proc/version` reported `#1 SMP PREEMPT Fri Feb 7 15:20:58 UTC 2025` instead of the stock firmware timestamp `#1 SMP PREEMPT Thu Mar 12 04:26:13 UTC 2026`. Additionally, the previous `sed -i '/UTS_VERSION=/a ...'` matched two separate lines in `scripts/mkcompile_h`.
- **Fix**: Anchored the `sed` replacement to `^UTS_VERSION="#\$VERSION"` in `scripts/mkcompile_h` and set `TIMESTAMP="Thu Mar 12 04:26:13 UTC 2026"` alongside `LINUX_COMPILE_BY=build-user` and `LINUX_COMPILE_HOST=build-host`.

### 5. Removed Obsolete SUSFS v1.5 Config Flags, Cleaned Up Patch Files, and Added `.rej` Guard (Low)
- **Symptom**:
  1. Six legacy SUSFS v1.5.x flags (`CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT`, `CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT`, `CONFIG_KSU_SUSFS_SUS_OVERLAYFS`, `CONFIG_KSU_SUSFS_TRY_UMOUNT`, `CONFIG_KSU_SUSFS_SUS_SU`, `CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT`) were appended to `gki_defconfig` and silently dropped by Kconfig under SUSFS v2.3.0 (`gki-android13-5.15`).
  2. `50_add_susfs_in_gki-android13-5.15.patch` was copied into `common/` and left behind after patching.
  3. Only `fs/namespace.c.rej` and `fs/proc/task_mmu.c.rej` were cleaned up without verifying whether any other `.rej` files existed.
- **Fix**: Pruned defconfig injection to active SUSFS v2.3.0 options, removed temporary `.patch` files immediately after `patch -p1`, and added a `find . -name "*.rej"` fail-fast check.

### 6. Corrected `ksu_susfs` Verification Command in `README.md` (Low)
- **Symptom**: `README.md` instructed running `ksu_susfs susfs_show_version`, which returns `-EINVAL` in SUSFS v2.3.0.
- **Fix**: Updated documentation to use `ksu_susfs show version` and `ksu_susfs show enabled_features`.

---

## 2026-10-28 — Doze Mode & Deep Sleep Reboot Fix

### Resolved Device Reboot When Entering Doze Mode (High)
- **Symptom**: Device rebooted when entering Android Doze mode / deep sleep (`PM_SUSPEND_MEM`).
- **Root Causes**:
  1. Missing PSCI CPUIdle domain coordination (`CONFIG_ARM_PSCI_CPUIDLE_DOMAIN`, `CONFIG_DT_IDLE_STATES`, `CONFIG_CPU_IDLE_MULTIPLE_DRIVERS`, `CONFIG_PM_GENERIC_DOMAINS_SLEEP`) for the Unisoc Tiger T612 asymmetric big.LITTLE clusters (2x Cortex-A75 + 6x Cortex-A55).
  2. Missing `CONFIG_SUSPEND_SKIP_SYNC=y`, causing synchronous eMMC filesystem flushes during sleep entry to stall and trip the Unisoc PMIC hardware watchdog (`sprd_watchdog_pmic`).
  3. Custom ROM / GSI background `init` property actions executing under `u:r:magisk:s0` or `u:r:su:s0` failing `setexeccon` with `EINVAL` and causing PID 1 (`init`) to abort (`SIGABRT`).
- **Fix**: Enabled the Unisoc T612 PSCI idle domain and `CONFIG_SUSPEND_SKIP_SYNC=y` options in `gki_defconfig`, injected permissive `magisk` and `su` domains into `rules.c`, and sanitized raw `BUG()` calls in `selinux_hide.c`.
