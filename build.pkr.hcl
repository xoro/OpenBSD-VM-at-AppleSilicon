###############################################################################
# Use at least this packer version
###############################################################################
packer {
  required_version = ">= 1.8.0"
}

###############################################################################
# Installing Plugins
###############################################################################
packer {
  required_plugins {
    vmware = {
      version = "= 1.0.7"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

###############################################################################
# Defining Locals
###############################################################################
#locals {
#  number_of_ports       = length(convert({ "www" = "80" }, map(string)))
#  default-communicator  = "ssh"
#  default-cpus-virt     = "4"
#  default-cpus-emu      = "4"
#  default-memory        = "4096"
#  default-disk_size     = "50000"
#  default-host-port-min = "54321"
#  default-host-port-max = "54321"
#  default-vnc-port-min  = "5999"
#  default-vnc-port-max  = "5999"
#  root-username         = "root"
#  root-password         = "root"
#  # OpenBSD specific stuff
#  openbsd-version          = "${var.openbsd-version}"
#  openbsd-version-short    = replace("${var.openbsd-version}", ".", "")
#  openbsd-iso-url          = "https://cdn.openbsd.org/pub/OpenBSD/${local.openbsd-version}/amd64/install${local.openbsd-version-short}.iso"
#  openbsd-iso-checksum     = "file:https://cdn.openbsd.org/pub/OpenBSD/${local.openbsd-version}/amd64/SHA256"
#  openbsd-shutdown-command = "shutdown -p now"
#}

###############################################################################
# Defining Variables
###############################################################################
variable "openbsd-boot-command-vmware" {
  type = list(string)
  default = [
    "install<wait1s><return><wait1s>",
    "default<wait1s><return><wait1s>",
    "flyingddns<wait1s><return><wait1s>",
    "<wait1s><return><wait1s>",
    "autoconf<wait1s><return><wait10s>",
    "none<wait1s><return><wait1s>",
    "done<wait1s><return><wait1s>",
    "root<wait1s><return><wait1s>",
    "root<wait1s><return><wait1s>",
    "yes<wait1s><return><wait1s>",
    "no<wait1s><return><wait1s>",
    "no<wait1s><return><wait1s>",
    "no<wait1s><return><wait1s>",
    "yes<wait1s><return><wait1s>",
    "<wait1s><return><wait1s>",
    "<wait1s><return><wait1s>",
    "whole<wait1s><return><wait1s>",
    "edit<wait1s><return><wait1s>",
    "zz<wait1s><return><wait1s>",
    "a b<wait1s><return><wait1s>",
    "<wait1s><return><wait1s>",
    "1G<wait1s><return><wait1s>",
    "swap<wait1s><return><wait1s>",
    "a a<wait1s><return><wait1s>",
    "<wait1s><return><wait1s>",
    "<wait1s><return><wait1s>",
    "<wait1s><return><wait1s>",
    "/<wait1s><return><wait1s>",
    "write<wait1s><return><wait1s>",
    "quit<wait1s><return><wait1s>",
    "cd0<wait1s><return><wait1s>",
    "<wait1s><return><wait1s>",
    "done<wait1s><return><wait1s>",
    "yes<wait1s><return><wait300s>",
    "done<wait1s><return><wait150s>",
    "reboot<wait1s><return><wait120s>",
    "root<wait1s><return><wait1s>",
    "root<wait1s><return><wait2s>",
    "exit<wait1s><return><wait1s>",
  ]
}

###############################################################################
# Defining the Builds
###############################################################################
# OpenBSD AMD64
##############################################################################
build {
  name = "openbsd-build"
  sources = [
    "sources.vmware-iso.openbsd-arm64",
  ]
  # Copy the ssh pub key to the vm
  provisioner "file" {
    source      = pathexpand("~/.ssh/id_ed25519.pub")
    destination = "/root/.ssh/authorized_keys"
  }
}

###############################################################################
# Defining the Sources
###############################################################################
source "vmware-iso" "openbsd-arm64" {
  vm_name          = "openbsd-arm64"
  communicator     = "ssh"
  ssh_username     = "root"
  ssh_password     = "root"
  shutdown_command = "shutdown -p now"
  headless         = "true"
  skip_export      = "true"
  skip_compaction  = "true"
  cpus             = "2"
  memory           = "4096"
  disk_size        = "64000"
  boot_wait        = "25s"
  iso_url          = "miniroot72.iso"
  iso_checksum     = "md5:d41d8cd98f00b204e9800998ecf8427e"
  boot_command     = "${var.openbsd-boot-command-vmware}"
  vmx_data = {
    "nvme0.present" = "TRUE"
    "nvme0:0.fileName" = "miniroot72.vmdk"
    "nvme0:0.present" = "TRUE"
    "bios.hddOrder" = "nvme0:0"
  }
#  vmx_data_post = {
#  }
  #keep_registered  = "true"
}
