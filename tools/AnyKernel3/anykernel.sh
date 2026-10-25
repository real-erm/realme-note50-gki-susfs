### AnyKernel3 Ramdisk Mod Script
## GKI 2.0 Generic Kernel Image Installer
## Optimized for Realme Note 50 (UMS9230 / Unisoc T612) and GKI 2.0 Devices

### AnyKernel setup
# global properties
properties() { '
kernel.string=Realme Note 50 GKI 2.0 KernelSU + SUSFS (SELinux Enforcing)
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=RMX3834
device.name2=realme_note_50
device.name3=UMS9230
device.name4=ums9230_1h10
device.name5=generic
supported.versions=13, 14, 15
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### AnyKernel install
# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# GKI 2.0 fast direct kernel flash (boot partition contains solely the kernel Image)
split_boot;
flash_boot;
## end boot install
