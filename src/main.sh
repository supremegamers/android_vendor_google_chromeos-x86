use std::print::log;

function main() {
	local _workdir && _workdir="$(readlink -f "$PWD")";
	local -r _version="14526.57.0_nocturne"
	local -r _url="https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_${_version}_recovery_stable-channel_mp.bin.zip";
	local -r _downloaded_file="$_workdir/${_url##*/}";
	local -r _shasum=6745c05f28e5d9ca574c385d7057327debbe7225;
	local -r _tmpdir="$_workdir/.cros_tmp";
	local -r _cros_extracted_dir="$_workdir/cros_extracted";
	local -r _vendor_img_path="opt/google/containers/android/vendor.raw.img";
	local _houdini_files=(
		bin/houdini
		bin/houdini64
		etc/binfmt_misc
		lib/libhoudini.so
		lib/arm
		lib64/libhoudini.so
		lib64/arm64
	)
	local _widevine_files=(
		vendor/bin/hw/android.hardware.drm@1.1-service.widevine
		vendor/etc/init/android.hardware.drm@1.1-service.widevine.rc
		vendor/lib/libwvhidl.so
	)
	rm -rf "$_tmpdir" "$_cros_extracted_dir";

	if ! sha1sum -c <<< "$_shasum $_downloaded_file" > /dev/null 2>&1; then {
		if test ! -e "$_downloaded_file"; then {
			log::info "Downloading $_downloaded_file";
		} else {
			log::warn "$_downloaded_file is corrupted, redownloading";
			rm -f "$_downloaded_file";
		} fi
		curl -L "$_url" -o "$_downloaded_file";
	} fi

	pushd "$_tmpdir";
	7z x "$_downloaded_file" ROOT-A.img;
	7z x "$_tmpdir/ROOT-A.img" "$_vendor_img_path";
	unsquashfs -user-xattrs "$_vendor_img_path" && squashfs-root;
	rsync -r --info=progress2 "${_houdini_files[@]}" "${_widevine_files[@]}" "$_cros_extracted_dir";
	mv "$_cros_extracted_dir/houdini/lib/arm/cpuinfo.pure32" "$_cros_extracted_dir/houdini/lib/arm/cpuinfo";

}
