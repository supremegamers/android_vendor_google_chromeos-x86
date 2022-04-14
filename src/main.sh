use std::print::log;


function main() {
	local sevenz='7z x -bso0 -bsp0';
	local _workdir && _workdir="$(readlink -f "$PWD")";
	local -r _version="14526.57.0_nocturne"
	local -r _url="https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_${_version}_recovery_stable-channel_mp.bin.zip";
	local -r _downloaded_file="$_workdir/${_url##*/}";
	local -r _shasum=6745c05f28e5d9ca574c385d7057327debbe7225;
	local -r _vendor_img_path="opt/google/containers/android/vendor.raw.img";
	local -r _root_partition_img_name="ROOT-A.img";
	local -r _tmpdir="$_workdir/.cros_tmp";
	local -r _cros_extracted_dir="$_workdir/cros_extracted";
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
		bin/hw/android.hardware.drm@1.1-service.widevine
		etc/init/android.hardware.drm@1.1-service.widevine.rc
		lib/libwvhidl.so
	)

	log::info "Assert shasum of ${_downloaded_file##*/} if exists";
	if ! sha1sum -c <<< "$_shasum $_downloaded_file" > /dev/null 2>&1; then {
		if test ! -e "$_downloaded_file"; then {
			log::info "Downloading ${_downloaded_file##*/}";
		} else {
			log::warn "${_downloaded_file##*/} is corrupted, redownloading";
			rm -f "$_downloaded_file";
		} fi
		curl -L "$_url" -o "$_downloaded_file";
	} fi

	for _dir in "$_tmpdir" "$_cros_extracted_dir"; do rm -rf "$_dir" && mkdir -m0755 "$_dir"; done
	trap "log::warn \"Performing cleanup\"; rm -rf \"$_tmpdir\"" EXIT SIGINT SIGTERM;
	pushd "$_tmpdir" 1>/dev/null && log::info "Extracting houdini and widevine from vendor.img";
	$sevenz "$_downloaded_file" && $sevenz *.bin "$_root_partition_img_name";
	$sevenz "$_root_partition_img_name" "$_vendor_img_path";
	unsquashfs -user-xattrs "$_vendor_img_path" >/dev/null 2>&1 && pushd squashfs-root 1>/dev/null;
	local _found_files && for _file in "${_houdini_files[@]}" "${_widevine_files[@]}"; do {
		if test -e "$_file"; then {
			local _parent_dir="${_file%/*}";
			log::info "Extracting $_file";
			if test "$_parent_dir" != "$_file"; then {
				mkdir -p -m0755 "$_cros_extracted_dir/${_parent_dir}";
				mv "$_file" "$_cros_extracted_dir/$_parent_dir";
			} else {
				mv "$_file" "$_cros_extracted_dir";
			} fi
			_found_files+=("$_file");
		} fi
	} done
	mv "$_cros_extracted_dir/lib/arm/cpuinfo.pure32" "$_cros_extracted_dir/lib/arm/cpuinfo" || :;

	if [[ "${_found_files[@]}" =~ (^| )lib/arm($| ) ]] && [[ "${_found_files[@]}" =~ (^| )lib64/arm64($| ) ]]; then {
		log::info "This image got both arm variants for houdini";
	} elif [[ "${_found_files[@]}" =~ (^| )lib/arm($| ) ]]; then {
		log::warn "This image only got arm32 variant for houdini";
	} elif [[ "${_found_files[@]}" =~ (^| )lib64/arm64($| ) ]]; then {
		log::warn "This image only got arm64 variant for houdini";
	} else {
		log::warn "This image got no houdini!!!!";
	} fi

	mkdir -p -m0755 "$_cros_extracted_dir/etc/init";
 	printf '%s\n' '# Enable native bridge for target executables

on early-init
    mount binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
on property:ro.enable.native.bridge.exec=1
    copy /system/etc/binfmt_misc/arm_exe /proc/sys/fs/binfmt_misc/register
    copy /system/etc/binfmt_misc/arm_dyn /proc/sys/fs/binfmt_misc/register
on property:ro.enable.native.bridge.exec64=1
    copy /system/etc/binfmt_misc/arm64_exe /proc/sys/fs/binfmt_misc/register
    copy /system/etc/binfmt_misc/arm64_dyn /proc/sys/fs/binfmt_misc/register
' > "$_cros_extracted_dir/etc/init/houdini.rc";

	log::info "Check $_cros_extracted_dir for output";

}
