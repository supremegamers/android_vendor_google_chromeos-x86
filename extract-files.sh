#!/usr/bin/env bash
set -euo pipefail
debug="n"

while test $# -gt 0
do
  case $1 in

  # Normal option processing
    -h | --help)
      echo "Usage: $0 options "
      echo "options: -h | --help: displays this dialog"
      echo "		 -d | --debug: Drives will stay mounted for debugging purposes"
      echo "		 -v | --version: Displays version info"
      echo ""
      ;;
    -d | --debug)
      debug="y";
      echo "Debug Mode: Drives will stay mounted"
      ;;
    -v | --version)
      echo "Version: vendor_google_chromeos-x86 2.1"
      echo "Updated: 05.27.2021"
      ;;
	
  # ...

  # Special cases
    --)
      break
      ;;
    --*)
      # error unknown (long) option $1
      ;;
    -?)
      # error unknown (short) option $1
      ;;

  # FUN STUFF HERE:
  # Split apart combined short options
    -*)
      split=$1
      shift
      set -- $(echo "$split" | cut -c 2- | sed 's/./-& /g') "$@"
      continue
      ;;

  # Done with options
    *)
      break
      ;;
  esac

  # for testing purposes:
  shift
done

# Use consistent umask for reproducible builds

umask 022

# Instructions for updating:
# Start by grabbing the latest recovery available
# Example: https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13816.82.0_hatch_recovery_stable-channel_mp-v6.bin.zip
# Then once downloaded, we run 'sha1sum chromeos_13816.82.0_hatch_recovery_stable-channel_mp-v6.bin.zip' 
# and it will generate our SHA1 sum. Add just the hash from that to the CHROMEOS_SHA1 string
# Then we split the name into the separate parts for CHROMEOS_VERSION & CHROMEOS_RECOVERY

CHROMEOS_VERSION="14268.67.0_hatch"
CHROMEOS_RECOVERY="chromeos_${CHROMEOS_VERSION}_recovery_stable-channel_mp-v6"

CHROMEOS_FILENAME="$CHROMEOS_RECOVERY.bin.zip"
CHROMEOS_URL="https://dl.google.com/dl/edgedl/chromeos/recovery/$CHROMEOS_FILENAME"
CHROMEOS_SHA1="7572ae077c0e771025f96b15f5c981013d771bd5 $CHROMEOS_FILENAME"

CHROMEOS_FILE="$PWD/$CHROMEOS_FILENAME"
TARGET_DIR="$PWD/proprietary"

read -rp "This script requires 'sudo' to mount the partitions in the ChromeOS recovery image. Continue? (Y/n) " choice
[[ -z "$choice" || "${choice,,}" == "y" ]]

echo "Checking ChromeOS image..."
if ! sha1sum -c <<< "$CHROMEOS_SHA1" 2> /dev/null; then
    if command -v curl &> /dev/null; then
        curl -fLo "$CHROMEOS_FILENAME" "$CHROMEOS_URL"
    elif command -v wget &> /dev/null; then
        wget -O "$CHROMEOS_FILENAME" "$CHROMEOS_URL"
    else
        echo "This script requires 'curl' or 'wget' to download the ChromeOS recovery image."
        echo "You can install one of them with the package manager provided by your distribution."
        echo "Alternatively, download $CHROMEOS_URL manually and place it in the current directory."
        exit 1
    fi

    sha1sum -c <<< "$CHROMEOS_SHA1"
fi

temp_dir=$(mktemp -d)
cd "$temp_dir"

function cleanup() {
	if [ "$debug" != "n" ]; then
		set +e
		cd "$temp_dir"
		mountpoint -q vendor && sudo umount vendor
		mountpoint -q chromeos && sudo umount chromeos
		[[ -n "${loop_dev:-}" ]] && sudo losetup -d "$loop_dev"
		rm -r "$temp_dir"
	else
		echo "Temp folder: $temp_dir"
	fi 
    
}
if [ "$debug" != "n" ]; then
trap cleanup EXIT
fi

CHROMEOS_EXTRACTED="$CHROMEOS_RECOVERY.bin"
CHROMEOS_ANDROID_VENDOR_IMAGE="chromeos/opt/google/vms/android/vendor.raw.img"


echo " -> Extracting recovery image"
unzip -q "$CHROMEOS_FILE" "$CHROMEOS_EXTRACTED"

echo " -> Mounting partitions"
# Setup loop device
loop_dev=$(sudo losetup -r -f --show --partscan "$CHROMEOS_EXTRACTED")

mkdir chromeos
sudo mount -r "${loop_dev}p3" chromeos
if [ "$debug" != "n" ]; then
read -p "Debug: finished mounting chromeos partition. Press any key to continue... " -n1 -s
fi
mkdir vendor
sudo mount -r "$CHROMEOS_ANDROID_VENDOR_IMAGE" vendor
if [ "$debug" != "n" ]; then
read -p "Debug: finished mounting vendor partition. Press any key to continue... " -n1 -s
fi
echo " -> Deleting old files"
rm -rf "$TARGET_DIR"
mkdir "$TARGET_DIR"
echo "$CHROMEOS_VERSION" > "$TARGET_DIR/version"

echo " -> Copying files"
RSYNC="rsync -rt --files-from=-"

# Widevine DRM
$RSYNC . "$TARGET_DIR/widevine" <<EOF
vendor/bin/hw/android.hardware.drm@1.3-service.widevine
vendor/etc/init/android.hardware.drm@1.3-service.widevine.rc
vendor/etc/vintf/manifest/manifest_android.hardware.drm@1.3-service.widevine.xml
vendor/lib/libwvhidl.so
vendor/lib/mediadrm/libwvdrmengine.so
vendor/lib64/mediadrm/libwvdrmengine.so
EOF

# Copy Android.bp for android.hardware.drm@1.3-service.widevine
#~ cp $PWD/vendor/google/chromeos-x86/assets/widevine.Android.bp $TARGET_DIR/widevine/Android.bp

cat > "$TARGET_DIR/widevine/Android.bp" <<EOF
cc_prebuilt_binary {
    name: "android.hardware.drm@1.3-service.widevine",
    srcs: ["vendor/bin/hw/android.hardware.drm@1.3-service.widevine"],
    vendor: true,
    relative_install_path: "hw",
    vintf_fragments: ["vendor/etc/vintf/manifest/manifest_android.hardware.drm@1.3-service.widevine.xml"],
    init_rc: ["vendor/etc/init/android.hardware.drm@1.3-service.widevine.rc"],
    required: [
        "libwvhidl",
        "libwvdrmengine",
    ],
    check_elf_files: false,
}
cc_prebuilt_library_shared {
    name: "libwvhidl",
    srcs: ["vendor/lib/libwvhidl.so"],
    vendor: true,
    check_elf_files: false,
}
cc_prebuilt_library_shared {
    name: "libwvdrmengine",
    srcs: ["vendor/lib/mediadrm/libwvdrmengine.so"],
    vendor: true,
    relative_install_path: "mediadrm",
    check_elf_files: false,
}

EOF

# Native bridge (Houdini)

# Create init script
mkdir -p "$TARGET_DIR/houdini/etc/init"
cat > "$TARGET_DIR/houdini/etc/init/houdini.rc" <<EOF
# Enable native bridge for target executables
on early-init
    mount binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc

on property:ro.enable.native.bridge.exec=1
    copy /system/etc/binfmt_misc/arm_exe /proc/sys/fs/binfmt_misc/register
    copy /system/etc/binfmt_misc/arm_dyn /proc/sys/fs/binfmt_misc/register

on property:ro.enable.native.bridge.exec64=1
    copy /system/etc/binfmt_misc/arm64_exe /proc/sys/fs/binfmt_misc/register
    copy /system/etc/binfmt_misc/arm64_dyn /proc/sys/fs/binfmt_misc/register
EOF
touch -hr vendor/etc/init "$TARGET_DIR/houdini/etc/init"{/houdini.rc,}

# Copy files
$RSYNC vendor "$TARGET_DIR/houdini" <<EOF
bin/houdini
bin/houdini64
etc/binfmt_misc
lib/libhoudini.so
lib/arm
lib64/libhoudini.so
lib64/arm64
EOF

# It's not quite clear what is the purpose of cpuinfo.pure32...
# The 32-bit version of Houdini cannot emulate aarch64 (afaik),
# so there is little point in pretending to be an ARMv8 processor...
# Continue using the ARMv7 version for now.
#~ mv "$TARGET_DIR/houdini/lib/arm/cpuinfo.pure32" "$TARGET_DIR/houdini/lib/arm/cpuinfo"
#~ touch -hr vendor/lib/arm "$TARGET_DIR/houdini/lib/arm"

# Normalize file modification times
touch -hr "$CHROMEOS_ANDROID_VENDOR_IMAGE" "$TARGET_DIR"{/*,}

echo "Done"
