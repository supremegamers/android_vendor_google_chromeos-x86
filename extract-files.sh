#!/usr/bin/env bash
main@bashbox%17122 () 
{ 
    function process::self::exit () 
    { 
        local _r=$?;
        kill -USR1 "$___self_PID";
        exit $_r
    };
    function process::self::forcekill () 
    { 
        exec 2> /dev/null;
        kill -9 "$___self_PID"
    };
    function log::error () 
    { 
        local _retcode="${2:-$?}";
        local _exception_line="$1";
        local _source="${BB_ERR_SOURCE:-"${BASH_SOURCE[-1]}"}";
        if [[ ! "$_exception_line" == "("*")" ]]; then
            { 
                echo -e "[!!!] \033[1;31merror\033[0m[$_retcode]: ${_source##*/}[$BASH_LINENO]: ${BB_ERR_MSG:-"$_exception_line"}" 1>&2;
                if test -v BB_ERR_MSG; then
                    { 
                        echo -e "STACK TRACE: (TOKEN: $_exception_line)" 1>&2;
                        local -i _frame=0;
                        local _treestack='|--';
                        local _line _caller _source;
                        while read -r _line _caller _source < <(caller "$_frame"); do
                            { 
                                echo "$_treestack ${_caller} >> ${_source##*/}::${_line}" 1>&2;
                                _frame+=1;
                                _treestack+='--'
                            };
                        done
                    };
                fi
            };
        else
            { 
                echo -e "[!!!] \033[1;31merror\033[0m[$_retcode]: ${_source##*/}[$BASH_LINENO]: SUBSHELL EXITED WITH NON-ZERO STATUS" 1>&2
            };
        fi;
        return "$_retcode"
    };
    \command \unalias -a || exit;
    set -eEuT -o pipefail;
    shopt -s inherit_errexit expand_aliases;
    trap 'exit' USR1;
    trap 'BB_ERR_MSG="UNCAUGHT EXCEPTION" log::error "$BASH_COMMAND" || process::self::exit' ERR;
    ___self="$0";
    ___self_PID="$$";
    ___MAIN_FUNCNAME="main@bashbox%17122";
    ___self_NAME="extract-cros_x86-houdini";
    ___self_CODENAME="cros_x86-houdini";
    ___self_AUTHORS=("AXON <axonasif@gmail.com>");
    ___self_VERSION="1.0";
    ___self_DEPENDENCIES=(std::0.2.0);
    ___self_REPOSITORY="";
    ___self_BASHBOX_COMPAT="0.3.9~";
    function bashbox::build::after () 
    { 
        local _target="extract-files.sh";
        cp "$_target_workfile" "$_arg_path/$_target";
        chmod +x "$_arg_path/$_target"
    };
    function log::info () 
    { 
        echo -e "[%%%] \033[1;37minfo\033[0m: $@"
    };
    function log::warn () 
    { 
        echo -e "[***] \033[1;37mwarn\033[0m: $@"
    };
    function main () 
    { 
        local sevenz='7z x -bso0 -bsp0';
        local _workdir && _workdir="$(readlink -f "$PWD")";
        local -r _version="14526.57.0_nocturne";
        local -r _url="https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_${_version}_recovery_stable-channel_mp.bin.zip";
        local -r _downloaded_file="$_workdir/${_url##*/}";
        local -r _shasum=6745c05f28e5d9ca574c385d7057327debbe7225;
        local -r _vendor_img_path="opt/google/containers/android/vendor.raw.img";
        local -r _root_partition_img_name="ROOT-A.img";
        local -r _tmpdir="$_workdir/.cros_tmp";
        local -r _cros_extracted_dir="$_workdir/cros_extracted";
        local _houdini_files=(bin/houdini bin/houdini64 etc/binfmt_misc lib/libhoudini.so lib/arm lib64/libhoudini.so lib64/arm64);
        local _widevine_files=(bin/hw/android.hardware.drm@1.1-service.widevine etc/init/android.hardware.drm@1.1-service.widevine.rc lib/libwvhidl.so);
        log::info "Assert shasum of ${_downloaded_file##*/} if exists";
        if ! sha1sum -c <<< "$_shasum $_downloaded_file" > /dev/null 2>&1; then
            { 
                if test ! -e "$_downloaded_file"; then
                    { 
                        log::info "Downloading ${_downloaded_file##*/}"
                    };
                else
                    { 
                        log::warn "${_downloaded_file##*/} is corrupted, redownloading";
                        rm -f "$_downloaded_file"
                    };
                fi;
                curl -L "$_url" -o "$_downloaded_file"
            };
        fi;
        for _dir in "$_tmpdir" "$_cros_extracted_dir";
        do
            rm -rf "$_dir" && mkdir -m0755 "$_dir";
        done;
        trap "log::warn \"Performing cleanup\"; rm -rf \"$_tmpdir\"" EXIT SIGINT SIGTERM;
        pushd "$_tmpdir" > /dev/null && log::info "Extracting vendor.img from ${_downloaded_file##*/}";
        $sevenz "$_downloaded_file" && $sevenz *.bin "$_root_partition_img_name";
        $sevenz "$_root_partition_img_name" "$_vendor_img_path";
        unsquashfs -user-xattrs "$_vendor_img_path" > /dev/null 2>&1 && pushd squashfs-root > /dev/null;
        local _found_files && for _file in "${_houdini_files[@]}" "${_widevine_files[@]}";
        do
            { 
                if test -e "$_file"; then
                    { 
                        local _parent_dir="${_file%/*}";
                        log::info "Extracting $_file";
                        if test "$_parent_dir" != "$_file"; then
                            { 
                                mkdir -p -m0755 "$_cros_extracted_dir/${_parent_dir}";
                                mv "$_file" "$_cros_extracted_dir/$_parent_dir"
                            };
                        else
                            { 
                                mv "$_file" "$_cros_extracted_dir"
                            };
                        fi;
                        _found_files+=("$_file")
                    };
                fi
            };
        done;
        mv "$_cros_extracted_dir/lib/arm/cpuinfo.pure32" "$_cros_extracted_dir/lib/arm/cpuinfo" || :;
        if [[ "${_found_files[@]}" =~ (^| )lib/arm($| ) ]] && [[ "${_found_files[@]}" =~ (^| )lib64/arm64($| ) ]]; then
            { 
                log::info "This image got both arm variants for houdini"
            };
        else
            if [[ "${_found_files[@]}" =~ (^| )lib/arm($| ) ]]; then
                { 
                    log::warn "This image only got arm32 variant for houdini"
                };
            else
                if [[ "${_found_files[@]}" =~ (^| )lib64/arm64($| ) ]]; then
                    { 
                        log::warn "This image only got arm64 variant for houdini"
                    };
                else
                    { 
                        log::warn "This image got no houdini!!!!"
                    };
                fi;
            fi;
        fi;
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
        log::info "Check $_cros_extracted_dir for output"
    };
    main "$@";
    wait;
    exit
}
main@bashbox%17122 "$@";
