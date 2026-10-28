# Realme Note 50 GKI 2.0 (SUSFS) — Static Audit & Bugfix Log

This document tracks bugs discovered and resolved in the `real-erm/realme-note50-gki-susfs` build pipeline, kernel configuration, and SUSFS packaging for the **Realme Note 50 (`RMX3834`, Unisoc Tiger T612 / `UMS9230`)**.

---

## 2026-10-28 — Second Static Audit: Critical & Root-Hiding Fixes

### 1. Sanitized `/sys/kernel/kheaders.tar.xz` (`CONFIG_IKHEADERS=y`) Header & `autoconf.h` Leaks (Critical — Root Hiding)
- **Symptom**: Even when `/proc/config.gz` was spoofed with `config/stock_defconfig`, `/sys/kernel/kheaders.tar.xz` embedded `include/linux/susfs.h`, `include/linux/susfs_def.h`, `include/config/ksu/*`, and `include/generated/autoconf.h` containing `#define CONFIG_KSU 1` and `#define CONFIG_KSU_SUSFS 1`.
- **Root Cause**: `kernel/gen_kheaders.sh` packs all `*.h` files from both `$(srctree)/include/` and `$(objtree)/include/` into `kernel/kheaders_data.tar.xz` without filtering out SUSFS or KSU headers and Kconfig symbols.
- **Fix**: Patched `kernel/gen_kheaders.sh` to remove `susfs.h`, `susfs_def.h`, and `include/config/ksu*` from the temporary `$cpio_dir` staging directory and strip `CONFIG_KSU*` lines from the staged `include/generated/autoconf.h` before creating `kheaders_data.tar.xz`.

### 2. Activated Runtime SUSFS Protections & Fixed Read-Only Path Bug in `susfs4ksu-module.zip` (Critical — Root Hiding & Functionality)
- **Symptom**: Flashing `susfs4ksu-module.zip` installed `/data/adb/ksu/bin/ksu_susfs` but activated zero runtime SUSFS protections.
- **Root Cause**:
  1. Upstream `simonpunk/susfs4ksu` wraps all commands in `post-fs-data.sh`, `service.sh`, and `boot-completed.sh` inside `cat <<EOF >/dev/null ... EOF` blocks or `#` comments as inert examples.
  2. Line 70 of upstream `post-fs-data.sh` wrote `cat /proc/bootconfig > ./fake_bootconfig.txt` (targeting read-only `/` during `post-fs-data`) instead of `${FAKE_BOOTCONFIG}`.
  3. `customize.sh` omitted `boot-completed.sh` from its `chmod 644` call.
- **Fix**: Configured `post-fs-data.sh`, `service.sh`, `boot-completed.sh`, and `customize.sh` during module packaging to automatically enable SELinux AVC log spoofing (`enable_avc_log_spoofing 1`), `/proc/bootconfig` spoofing (`green` / `locked` / `reboot`), stock `uname` timestamp spoofing, kernel log disabling (`enable_log 0`), `resetprop` verified-boot property sanitization, and `add_sus_path` / `add_sus_path_loop` hiding for recovery/loop paths.

### 3. Removed Unconditional `"magisk"` and `"su"` SELinux Domain Injection (Critical — Root Hiding)
- **Symptom**: Root detectors inspecting `/sys/fs/selinux/policy` (`pol_read_bin`) or querying security context SIDs could detect `DirtySepolicy` due to the presence of permissive `"magisk"` and `"su"` domains.
- **Root Cause**: `.github/workflows/build-kernel.yml` unconditionally injected `ksu_type(db, "magisk", "domain")` and `ksu_type(db, "su", "domain")` into `selinux/rules.c`. `selinux_hide.c` does not hook `/sys/fs/selinux/policy` binary policy reads, and injecting `"su"` is also redundant when `KERNEL_SU_DOMAIN` is already `"su"`.
- **Fix**: Removed the unconditional `"magisk"` and `"su"` domain injection from `selinux/rules.c` so compiled kernels maintain a clean SELinux policy.

### 4. Added Kernel-Level `/proc/cmdline` Bootloader & Verified Boot State Spoofing (`fs/proc/cmdline.c`) (High — Root Hiding)
- **Symptom**: Apps reading `/proc/cmdline` directly could still observe `androidboot.verifiedbootstate=orange`, `androidboot.vbmeta.device_state=unlocked`, or `androidboot.flash.locked=0`.
- **Root Cause**: On `gki-android13-5.15`, `50_add_susfs_in_gki-android13-5.15.patch` only hooks `fs/proc/bootconfig.c` (`boot_config_proc_show`) and leaves `fs/proc/cmdline.c` unpatched. On Unisoc Tiger T612 (`UMS9230`), U-Boot passes `androidboot.*` arguments via `/chosen/bootargs` into `/proc/cmdline` (`CONFIG_CMDLINE_EXTEND=y`).
- **Fix**: Patched `fs/proc/cmdline.c` (`proc_cmdline_init`) to initialize a sanitized `spoofed_command_line` buffer at `fs_initcall` that rewrites `verifiedbootstate=orange/yellow` $\rightarrow$ `green`, `vbmeta.device_state=unlocked` $\rightarrow$ `locked`, `flash.locked=0` $\rightarrow$ `1`, and `veritymode=disabled` $\rightarrow$ `enforcing` for all `/proc/cmdline` readers without altering internal `saved_command_line`.

### 5. Defaulted `susfs_is_log_enabled` to `false` at Boot in `fs/susfs.c` (High — Root Hiding)
- **Symptom**: SUSFS emitted `susfs:` operational logs to the kernel ring buffer (`dmesg`) during early boot before userspace scripts ran, and printed `"susfs: disable logging to kernel"` when `enable_log 0` was invoked.
- **Root Cause**: `fs/susfs.c` declared `DEFINE_STATIC_KEY_TRUE(susfs_is_log_enabled)` and called `pr_info("susfs: disable logging to kernel")` inside `susfs_enable_log()`.
- **Fix**: Patched `common/fs/susfs.c` to use `DEFINE_STATIC_KEY_FALSE(susfs_is_log_enabled)` and removed the `pr_info("susfs: disable logging to kernel")` call so SUSFS logging is completely silent from boot unless explicitly enabled for debugging.

### 6. Pinned `VERSION=1` in `scripts/mkcompile_h` (Low — Root Hiding)
- **Symptom**: Multiple link passes during `build/build.sh` could increment `.version` and produce `#2 SMP PREEMPT ...` in `UTS_VERSION`.
- **Fix**: Explicitly pinned `VERSION=1` alongside `TIMESTAMP`, `LINUX_COMPILE_BY`, and `LINUX_COMPILE_HOST` in `scripts/mkcompile_h`.

---

## 2026-10-28 — First Static Audit & Pipeline Fixes

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
