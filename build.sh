#!/bin/sh
#shellcheck disable=SC2009 #Consider using pgrep instead of grepping ps output.
#shellcheck disable=SC2317 #Command appears to be unreachable. Check usage (or ignore if invoked indirectly).

# Variables to make the text output more readable
export fmt_red_bold="\e[91m\033[1m"
export fmt_bold="\033[1m"
export fmt_end="\e[0m"
# Variables used by packer.
export PACKER_LOG="1"
export PACKER_LOG_PATH="log/packer.log"
# Variables used in this script
packer_config_file_name="openbsd-packer.pkr.hcl"
openbsd_version="$(grep -A 2 openbsd-version ${packer_config_file_name} | grep default | cut -d "\"" -f 2)"
openbsd_version_short="$(echo "${openbsd_version}" | tr -d .)"
use_openbsd_snapshot="$(grep -A 2 use-openbsd-snapshot ${packer_config_file_name} | grep default | cut -d "\"" -f 2)"
# Variables passed to packer

check_openbsd_install_image ()
{
    # We check if the user wants to use the latest development snapshot
    if [ "${use_openbsd_snapshot}" = "true" ]; then
        url_path="snapshots"
    else
        url_path="${openbsd_version}"
    fi
    # Check if the OpenBSD install image is available locally
    if [ ! -f install"${openbsd_version_short}".img ]; then
        printf "%b %bINFO:%b  Downloading the OpenBSD image file.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"
        if ! curl --progress-bar \
                  --remote-name \
                  https://cdn.openbsd.org/pub/OpenBSD/"${url_path}"/arm64/install"${openbsd_version_short}".img; then
            printf "%b %bERROR:%b Downloading the OpenBSD arm64 install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
            printf "%b %bERROR:%b Make sure you are connected to the internet correctly and can download the following file:\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
            printf "%b %bERROR:%b https://cdn.openbsd.org/pub/OpenBSD/%b/arm64/install%b.img\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}" "${openbsd_version}" "${openbsd_version_short}"
            exit 11
        fi
    fi
    # Check the sha256 checksum against the online availlable checksum at cdn.openbsd.org
    if ! install_sha256_locally="$(sha256sum "install${openbsd_version_short}.img" | cut -d " " -f 1)"; then
        printf "%b %bERROR:%b Checking the checksum of the local install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
        exit 12
    fi
    if ! install_sha256_online="$(curl --silent https://cdn.openbsd.org/pub/OpenBSD/${url_path}/arm64/SHA256 | grep "install${openbsd_version_short}.img" | cut -d " " -f 4)"; then
        printf "%b %bERROR:%b Downloading the checksum of the install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
        exit 13
    fi
    if [ "${install_sha256_locally}" != "${install_sha256_online}" ]; then
        printf "%b %bERROR:%b The sha256 checksum of the local \"install%b.img\" is not correct.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}" "${openbsd_version_short}" 
        printf "%b %bERROR:%b It is supposed to be: %b.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}" "${install_sha256_online}"
        printf "%b %bERROR:%b Do you want me to delete the local install img file? [Y\\\\n]: " "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
        read -r answer
        if [ "${answer}" = "" ] || [ "${answer}" = "Y" ] || [ "${answer}" = "y" ]; then
            if ! rm -rf install*.img; then
                printf "%b %bERROR:%b The install img file could not be deleted.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
                printf "%b %bERROR:%b Please try to delete it manually.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
                exit 14
            else
                printf "%b %bINFO:%b  The install img file was deleted successfully.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"
                return 1
            fi
        else
            printf "%b %bWARNIG%b  Please try to delete it manually and restart the build again.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
            exit 16
        fi
    fi
    printf "%b %bINFO:%b  The sha256 checksum of the install image is correct.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"
    return 0
}

printf "################################################################################\n"
printf "# Checking the software prerequisites\n"
printf "################################################################################\n"
# MacOS running on Apple silicon
if [ "$(uname -o) $(uname -m)" != "Darwin arm64" ]; then
    printf "%b %bERROR:%b This script is only working on MacOS running on Apple Silicon.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 5
fi
# Check if homebrew is installed (QUESTION: Is homebrew really required???)
if ! which brew > /dev/null 2>&1; then
    printf "%b %bERROR:%b Please install homebrew.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    printf "%b %bERROR:%b More infos at https://brew.sh\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 6
fi
# Check if curl is available on the system (it is included in the MacOS default installation)
if ! which curl > /dev/null 2>&1; then
    printf "%b %bERROR:%b curl is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    printf "%b %bERROR:%b Please install curl (brew install curl).\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 7
fi
# Check if sha256sum is available on the system
if ! which sha256sum > /dev/null 2>&1; then
    printf "%b %bERROR:%b sha256sum is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    printf "%b %bERROR:%b Please install sha256sum (brew install coreutils).\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 8
fi
# Check if qemu-img is installed
if ! which qemu-img > /dev/null 2>&1; then
    printf "%b %bERROR:%b qemu-img is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    printf "%b %bERROR:%b Please install qemu (brew install qemu).\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 9
fi
# Check if packer is installed (the packer version will be checked in the pkr.hcl script)
if ! which packer > /dev/null 2>&1; then
    printf "%b %bERROR:%b packer is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    printf "%b %bERROR:%b Please install packer (brew install packer).\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 10
fi
# Check if VMware Fusion is installed (at least the version 13 that supports arm64 VMs)
if ! brew list | grep vmware-fusion > /dev/null 2>&1; then
    printf "%b %bERROR:%b vmware-fusion is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    printf "%b %bERROR:%b Please install vmware-fusion (brew install vmware-fusion).\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 11
fi
# Check if vmrun is accessible
if ! which vmrun > /dev/null 2>&1; then
    printf "%b %bERROR:%b vmrun is not accessible on this system. Make sure VMware Fusion is installed correctly.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    printf "%b %bERROR:%b Please install vmware-fusion (brew install vmware-fusion).\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 12
fi
printf "%b %bINFO:%b  ALL software prerequisites are available on this system.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"

printf "################################################################################\n"
printf "# Cleaning up the directories and files\n"
printf "################################################################################\n"
if ! rm -rf output-* \
            tmp \
            ./*.vmdk \
            empty.iso \
            log/* \
            > /dev/null 2>&1; then
    printf "%b %bERROR:%b Cleanup of directories and files did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 13
fi
printf "%b %bINFO:%b  The local directories have been cleaned up.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"

printf "################################################################################\n"
printf "# Make sure the OpenBSD arm64 install image is available locally\n"
printf "################################################################################\n"
if ! check_openbsd_install_image; then
    check_openbsd_install_image
fi

printf "################################################################################\n"
printf "# Convert the current OpenBSD install image to a vmdk file\n"
printf "################################################################################\n"
if ! qemu-img convert install"${openbsd_version_short}".img -O vmdk install"${openbsd_version_short}".vmdk > /dev/null 2>&1; then
    printf "%b %bERROR:%b Coverting the OpenBSD install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 14
fi
printf "%b %bINFO:%b  The OpenBSD install image was successfully converted to a vmdk file.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"

printf "################################################################################\n"
printf "# Creating an empty (dummy) ISO image required by packer\n"
printf "################################################################################\n"

if ! (touch tmp && dd if=tmp of=empty.iso && rm -rf tmp) > /dev/null 2>&1; then
    printf "%b %bERROR:%b Creating an empty ISO file did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 15
fi
printf "%b %bINFO:%b  The dummy file empty.iso was successfully created.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"

printf "################################################################################\n"
printf "# Validating the packer configuration file\n"
printf "################################################################################\n"
if ! packer validate .; then
    printf "%b %bERROR:%b Validating the packer packer configuration file did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 16
fi
printf "%b %bINFO:%b  The packer configuration was successfully validated.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"

printf "################################################################################\n"
printf "# Initializing packer and get the required plugins\n"
printf "################################################################################\n"
if ! packer init .; then
    printf "%b %bERROR:%b Initializing packer did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 17
fi
printf "%b %bINFO:%b  packer was successfully initialized.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"

printf "################################################################################\n"
printf "# Installing OpenBSD in VMWare Fuison (this can take several minutes)\n"
printf "################################################################################\n"
if ! packer build -force -on-error=abort .; then
    printf "%b %bERROR:%b Building the OpenBSD VM did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    printf "%b %bERROR:%b You can check the log file in the log directory.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 18
fi
printf "%b %bINFO:%b  The OpenBSD VM was created successfully.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"

printf "################################################################################\n"
printf "# Removing the OpenBSD install installation image from the VM configuration\n"
printf "################################################################################\n"
if ! (sed -i '' '/^nvme0:1/d' output-*/*.vmx && \
     sed -i '' 's/bios.hddorder = "nvme0:1"/bios.hddorder = "nvme0:0"/g' output-*/*.vmx); then
    printf "%b %bERROR:%b Removing the OpenBSD instal installation image from the VM config did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_red_bold}" "${fmt_end}"
    exit 19
fi
printf "%b %bINFO:%b  Great, creating an OpenBSD VMWare guest on Apple Silicon succeeded!!!.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"
printf "%b %bINFO:%b  Just open the VMX file located in the output directory using VMWare Fusion and have fun running a virtualized OpenBSD on top of Apple Silicon. ;-)\n\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${fmt_bold}" "${fmt_end}"

exit 0

