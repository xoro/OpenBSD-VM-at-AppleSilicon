#!/bin/sh
# shellcheck disable=SC2009

# Variables used by packer.
export PACKER_LOG="1"
export PACKER_LOG_PATH="log/packer.log"
# Variables used in this script
openbsd_version_log="7.2"
openbsd_version_short="$(echo "${openbsd_version_log}" | tr -d .)"
max_tries_port_check="120"
packer_config_file_name="openbsd-packer.pkr.hcl"
# Variables passed to packer
packer_ssh_host="openbsd-packer"
openbsd_hostname="openbsd-packer"
openbsd_username="user"
openbsd_excluded_sets="-g* -x*"
rc_firsttime_wait="60"

printf "################################################################################\n"
printf "# Checking if there is still a vmware-vmx process left over from the last run\n"
printf "################################################################################\n"
if (ps aux | grep vmware-vmx | grep packer);
then
    printf "%s INFO:  There is a still running process related to this script.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s INFO:  Do want me to kill it [Y\\\\n]: " "$(date "+%Y-%m-%d %H:%M:%S")"
    read -r answer
    if [ "$answer" = "" ] || [ "$answer" = "Y" ] || [ "$answer" = "y" ];
    then
        if ! pkill vmware-vmx;
        then
            printf "%s ERROR: The vmware-vmx process could not be killed successfully.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
            printf "%s ERROR: Please check this manually, kill it and than rerun this script again.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
            exit 1
        else
            printf "%s INFO:  All vmware-vmx processes have been killed successfully.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"
        fi
    fi
else
    printf "%s INFO:  There is no running VMWare Fuiosn process related to this script.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"
fi

printf "################################################################################\n"
printf "# Checking if no process is using the TCP port localhost:5987\n"
printf "################################################################################\n"
i=0
while [ "${i}" -lt "${max_tries_port_check}" ]
do
    checked_ports=$(netstat -lnv | grep '127.0.0.1.5987'; lsof -i -P 2>/dev/null | grep localhost:5987)
    if [ "${checked_ports}" = "" ];
    then
        if [ "${i}" != "0" ];
        then
            printf "\n"
        fi
        break
    fi
    if [ "${i}" = "0" ];
    then
        printf "%s INFO:  Please make sure that all packer and VNC Viewer processes are closed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
        printf "%s INFO:  ." "$(date "+%Y-%m-%d %H:%M:%S")"
    else
        printf "."
    fi
    i=$(( i + 1 ))
    sleep 1
done
if [ "${i}" -lt "${max_tries_port_check}" ];
then
    printf "%s INFO:  There are no running packer and VNC Viewer processes anymore.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"
else
    printf "\n"
    printf "%s ERROR: There are running processes that are using the port 5987.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please make sure that all packer and VNC Viewer processes are closed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 1
fi

printf "################################################################################\n"
printf "# Checking the software prerequisites\n"
printf "################################################################################\n"
# MacOS running on Apple silicon
if [ "$(uname -o) $(uname -m)" != "Darwin arm64" ];
then
    printf "%s ERROR: This script is only working on MacOS running on Apple Silicon.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 2
fi
# Check if homebrew is installed (QUESTION: Is homebrew really required???)
if ! which brew > /dev/null 2>&1;
then
    printf "%s ERROR: Please install homebrew.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: More infos at https://brew.sh\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 3
fi
# Check if curl is available on the system (it is included in the MacOS default installation)
if ! which curl > /dev/null 2>&1;
then
    printf "%s ERROR: curl is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install curl (brew install curl).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 4
fi
# Check if sha256sum is available on the system
if ! which sha256sum > /dev/null 2>&1;
then
    printf "%s ERROR: sha256sum is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install sha256sum (brew install coreutils).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 5
fi
# Check if qemu-img is installed
if ! which qemu-img > /dev/null 2>&1;
then
    printf "%s ERROR: qemu-img is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install qemu (brew install qemu).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 6
fi
# Check if packer is installed (the packer version will be checked in the pkr.hcl script)
if ! which packer > /dev/null 2>&1;
then
    printf "%s ERROR: packer is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install packer (brew install packer).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 7
fi
# Check if VMware Fusion is installed (at least the version 13 that supports arm64 VMs)
if ! brew list | grep vmware-fusion > /dev/null 2>&1;
then
    printf "%s ERROR: vmware-fusion is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install vmware-fusion (brew install vmware-fusion).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 8
fi
# Check if vmrun is accessible
if ! which vmrun > /dev/null 2>&1;
then
    printf "%s ERROR: vmrun is not accessible on this system. Make sure VMware Fusion is installed correctly.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install vmware-fusion (brew install vmware-fusion).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 9
fi
printf "%s INFO:  ALL software prerequisites are available on this system.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "################################################################################\n"
printf "# Cleaning up the directories and files\n"
printf "################################################################################\n"
if ! rm -rf output-* \
            tmp \
            ./*.vmdk \
            empty.iso \
            log/* \
            > /dev/null 2>&1;
then
    printf "%s ERROR: Cleanup of directories and files did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 10
fi
printf "%s INFO:  The local directory has been cleaned up.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "################################################################################\n"
printf "# Make sure the OpenBSD arm64 install image is available locally\n"
printf "################################################################################\n"
# Check if the OpenBSD install image is available locally
if [ ! -f install"${openbsd_version_short}".img ]; then
    printf "%s INFO:  Downloading the OpenBSD image file.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    if ! curl --progress-bar \
              --remote-name \
              https://cdn.openbsd.org/pub/OpenBSD/"${openbsd_version_log}"/arm64/install"${openbsd_version_short}".img;
    then
        printf "%s ERROR: Downloading the OpenBSD arm64 install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
        printf "%s ERROR: Make sure you are connected to the internet correctly and can download the following file:\n" "$(date "+%Y-%m-%d %H:%M:%S")"
        printf "%s ERROR: https://cdn.openbsd.org/pub/OpenBSD/%s/arm64/install%s.img\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${openbsd_version_log}" "${openbsd_version_short}"
        exit 11
    fi
fi
# Check the sha256 checksum against the online availlable checksum at cdn.openbsd.org
if ! install_sha256_locally="$(sha256sum install72.img | cut -d " " -f 1)";
then
    printf "%s ERROR: Checking the checksum of the local install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 12
fi
if ! install_sha256_online="$(curl --silent https://cdn.openbsd.org/pub/OpenBSD/${openbsd_version_log}/arm64/SHA256 | grep install72.img | cut -d " " -f 4)";
then
    printf "%s ERROR: Downloading the checksum of the install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 13
fi
if [ "${install_sha256_locally}" != "${install_sha256_online}" ]; then
    printf "%s ERROR: The sha256 checksum of the local \"install%s.img\" is not correct.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${openbsd_version_short}"
    printf "%s ERROR: It is supposed to be: %s.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${install_sha256_online}"
    exit 14
    
fi
printf "%s INFO:  The sha256 checksum of the install image is correct.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "################################################################################\n"
printf "# Convert the current OpenBSD install image to a vmdk file\n"
printf "################################################################################\n"
if ! qemu-img convert install"${openbsd_version_short}".img -O vmdk install"${openbsd_version_short}".vmdk > /dev/null 2>&1;
then
    printf "%s ERROR: Coverting the OpenBSD install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 15
fi
printf "%s INFO:  The OpenBSD install image was successfully converted to a vmdk file.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "################################################################################\n"
printf "# Creating an empty (dummy) ISO image required by packer\n"
printf "################################################################################\n"

if ! (touch tmp && dd if=tmp of=empty.iso && rm -rf tmp) > /dev/null 2>&1;
then
    printf "%s ERROR: Creating an empty ISO file did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 16
fi
printf "%s INFO:  The dummy file empty.iso was successfully created.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "################################################################################\n"
printf "# Validating the packer configuration file\n"
printf "################################################################################\n"
if ! packer validate "${packer_config_file_name}";
then
    printf "%s ERROR: Validating the packer packer configuration file did not succed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 17
fi
printf "%s INFO:  The packer configuration was successfully validated.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "################################################################################\n"
printf "# Initializing packer and get the required plugins\n"
printf "################################################################################\n"
if ! packer init "${packer_config_file_name}" > /dev/null 2>&1;
then
    printf "%s ERROR: Initializing packer did not succed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 18
fi
printf "%s INFO:  packer was successfully initialized.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "################################################################################\n"
printf "# Installing OpenBSD in VMWare Fuison (this can take several minutes)\n"
printf "# Follow the VM creation: vnc://127.0.0.1:5987\n"
printf "################################################################################\n"
if ! packer build -force \
                  -on-error=abort \
                  -var packer-ssh-host="${packer_ssh_host}" \
                  -var openbsd-install-img="$(pwd)"/install"${openbsd_version_short}".vmdk \
                  -var openbsd-hostname="${openbsd_hostname}" \
                  -var openbsd-username="${openbsd_username}" \
                  -var openbsd-excluded-sets="${openbsd_excluded_sets}" \
                  -var rc-firsttime-wait="${rc_firsttime_wait}" \
                  "${packer_config_file_name}" > /dev/null 2>&1;
then
    printf "%s ERROR: Building the OpenBSD VM did not succed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: You can check the log file in the log directory.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 19
fi
printf "%s INFO:  The OpenBSD VM was created successfully.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "################################################################################\n"
printf "# Removing the OpenBSD install installation image from the VM configuration\n"
printf "################################################################################\n"
if ! (sed -i '' '/^nvme0:1/d' output-*/*.vmx && \
     sed -i '' 's/bios.hddorder = "nvme0:1"/bios.hddorder = "nvme0:0"/g' output-*/*.vmx);
then
    printf "%s ERROR: Removing the OpenBSD instal installation image from the VM config did not succed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 20
fi
printf "%s INFO:  Great, creating an OpenBSD VMWare guest on Apple Silicon succeeded!!!.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
printf "%s INFO:  Just open the VMX file located in the output directory using VMWare Fusion and have fun running a virtualized OpenBSD on top of Apple Silicon. ;-)\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

exit 0
