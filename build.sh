#!/bin/sh

export PACKER_LOG="1"
export PACKER_LOG_PATH="log/packer.log"
export OPENBSD_VERSION_LONG="7.2"
export OPENBSD_VERSION_SHORT=$(echo ${OPENBSD_VERSION_LONG} | tr -d .)

# TODO: Make sure that there are no running vmware (vmware-vmx) instances any more!!!

printf "###############################################################################\n"
printf "# Checking the software prerequisites\n"
printf "###############################################################################\n"
# MacOS running on Apple silicon
if [ "$(uname -o) $(uname -m)" != "Darwin arm64" ]; then
    printf "%s ERROR: This script is only working on MacOS running on Apple Silicon.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 1
fi
# Check if homebrew is installed (QUESTION: Is homebrew really required???)
which brew &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: Please install homebrew.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: More infos at https://brew.sh\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 2
fi
# Check if curl is available on the system (it is included in the MacOS default installation)
which curl &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: curl is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install curl (brew install curl).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 3
fi
# Check if sha256sum is available on the system
which sha256sum &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: sha256sum is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install sha256sum (brew install coreutils).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 4
fi
# Check if qemu-img is installed
which qemu-img &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: qemu-img is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install qemu (brew install qemu).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 5
fi
# Check if packer is installed (the packer version will be checked in the build.pkr.hcl script)
which packer &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: packer is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install packer (brew install packer).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 6
fi
# Check if VMware Fusion is installed (at least the version 13 that supports arm64 VMs)
brew list | grep vmware-fusion &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: vmware-fusion is not available on this system.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install vmware-fusion (brew install vmware-fusion).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 7
fi
# Check if vmrun is accessible
which vmrun &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: vmrun is not accessible on this system. Make sure VMware Fusion is installed correctly.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: Please install vmware-fusion (brew install vmware-fusion).\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 8
fi
printf "%s INFO:  ALL software prerequisites are available on this system.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "###############################################################################\n"
printf "# Cleanup the directories and files\n"
printf "###############################################################################\n"
rm -rf output-* tmp *.vmdk empty.iso log/* &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: Cleanup of directories and files did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 9
fi
printf "%s INFO:  The local directory has been cleaned up.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "###############################################################################\n"
printf "# Make sure the OpenBSD arm64 install image is available locally\n"
printf "###############################################################################\n"
# Check if the OpenBSD install image is available locally
if [ ! -f install${OPENBSD_VERSION_SHORT}.img ]; then
    printf "%s INFO:  Downloading OpenBSD image file.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    curl --progress-bar --remote-name https://cdn.openbsd.org/pub/OpenBSD/${OPENBSD_VERSION_LONG}/arm64/install${OPENBSD_VERSION_SHORT}.img
    if [ "$?" != "0" ]; then
        printf "%s ERROR: Downloading the OpenBSD arm64 install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
        printf "%s ERROR: Make sure you are connected to the internet correctly and can download the following file:\n" "$(date "+%Y-%m-%d %H:%M:%S")"
        printf "%s ERROR: https://cdn.openbsd.org/pub/OpenBSD/%s/arm64/install%s.img\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${OPENBSD_VERSION_LONG}" "${OPENBSD_VERSION_SHORT}"
        exit 10
    fi
fi
# Check the sha256 checksum against the online availlable checksum at cdn.openbsd.org
install_sha256_locally="$(sha256sum install72.img | cut -d " " -f 1)"
if [ "$?" != "0" ]; then
    printf "%s ERROR: Checking the checksum of the local install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 11
fi
install_sha256_online="$(curl --silent https://cdn.openbsd.org/pub/OpenBSD/${OPENBSD_VERSION_LONG}/arm64/SHA256 | grep install72.img | cut -d " " -f 4)"
if [ "$?" != "0" ]; then
    printf "%s ERROR: Downloading the checksum of the install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 12
fi
if [ "${install_sha256_locally}" != "${install_sha256_online}" ]; then
    printf "%s ERROR: The sha256 checksum of the local \"install%s.img\" is not correct.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${OPENBSD_VERSION_SHORT}"
    printf "%s ERROR: It is supposed to be: %s.\n" "$(date "+%Y-%m-%d %H:%M:%S")" "${install_sha256_online}"
    exit 13
    
fi
printf "%s INFO:  The sha256 checksum of the install image is correct.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "###############################################################################\n"
printf "# Convert the current OpenBSD install image to a vmdk file\n"
printf "###############################################################################\n"
qemu-img convert install${OPENBSD_VERSION_SHORT}.img -O vmdk install${OPENBSD_VERSION_SHORT}.vmdk &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: Coverting the OpenBSD install image did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 14
fi
printf "%s INFO:  The OpenBSD install image was successfully converted to a vmdk file.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "###############################################################################\n"
printf "# Creating an empty (dummy) ISO image required by packer\n"
printf "###############################################################################\n"
touch tmp &>/dev/null && \
dd if=tmp of=empty.iso &>/dev/null && \
rm -rf tmp &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: Creating an empty ISO file did not succeed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 15
fi
printf "%s INFO:  The dummy file empty.iso was successfully created.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "###############################################################################\n"
printf "# Initializing packer and get the required plugins\n"
printf "###############################################################################\n"
packer init build.pkr.hcl &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: Initializing packer did not succed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 16
fi
printf "%s INFO:  packer was successfully initialized.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

# TODO: Add a check to see if the port 127.0.0.1.5987 is not already open (or still open)
# netstat -ln | grep '127.0.0.1.5987'; echo $?
# We have to add some loop to check constantly for some seconds, if the open port was already freed.

printf "###############################################################################\n"
printf "# Installing OpenBSD in VMWare Fuison (this can take several minutes)\n"
printf "# Follow the VM creation: vnc://127.0.0.1:5987\n"
printf "###############################################################################\n"
packer build \
    -force \
    -on-error=abort \
    -var install-img="$(pwd)"/install${OPENBSD_VERSION_SHORT}.vmdk \
    build.pkr.hcl &>/dev/null
if [ "$?" != "0" ]; then
    printf "%s ERROR: Building the OpenBSD VM did not succed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    printf "%s ERROR: You can check the log file in the log directory.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 17
fi
printf "%s INFO:  The OpenBSD VM was created successfully.\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

printf "###############################################################################\n"
printf "# Removing the OpenBSD install installation image from the VM configuration\n"
printf "###############################################################################\n"
sed -i '' '/^nvme0:1/d' output-openbsd-packer/packer-openbsd-packer.vmx && \
sed -i '' 's/bios.hddorder = "nvme0:1"/bios.hddorder = "nvme0:0"/g' output-openbsd-packer/packer-openbsd-packer.vmx
if [ "$?" != "0" ]; then
    printf "%s ERROR: Removing the OpenBSD instal installation image from the VM config did not succed.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    exit 18
fi
printf "%s INFO:  Great, creating an OpenBSD VMWare guest on Apple Silicon succeeded!!!.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
printf "%s INFO:  Just open the VMX file located in the output directory using VMWare Fusion and have fun running a virtualized OpenBSD on top of Apple Silicon. ;-)\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"

exit 0
