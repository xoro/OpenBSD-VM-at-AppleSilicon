#!/bin/sh

if [ ! -f miniroot72.img ]; then
    printf "%s INFO:  Downloading OpenBSD image file.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    wget https://cdn.openbsd.org/pub/OpenBSD/7.2/arm64/miniroot72.img
else
    printf "%s INFO:  The OpenBSD image file was already downloaded.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
fi

if [ ! -f miniroot72.vmdk ]; then
    printf "%s INFO:  Converting the OpenBSD image file to a VMDK file.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    qemu-img convert miniroot72.img -O vmdk miniroot72.vmdk
else
    printf "%s INFO:  The OpenBSD image file was already converted to a VMDK file.\n" "$(date "+%Y-%m-%d %H:%M:%S")"
fi

rm -rf tmp && mkdir tmp && dd if=tmp of=miniroot72.iso

packer init build.pkr.hcl
packer validate build.pkr.hcl
packer build \
    -parallel-builds=1 \
    -color=false \
    -timestamp-ui \
    -force \
    -on-error=abort \
    build.pkr.hcl

exit 0
