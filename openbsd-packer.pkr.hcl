packer {
  required_version = ">= 1.8.0"
  required_plugins {
    vmware = {
      version = "= 1.0.7"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

variable "packer-ssh-host" {
  type    = string
  default = "openbsd-packer"
}
variable "packer-vnc-port" {
  type    = string
  default = "5987"
}
variable "openbsd-install-img" {
  type    = string
  default = "install72.img"
}
variable "openbsd-hostname" {
  type    = string
  default = "openbsd-packer"
}
variable "openbsd-username" {
  type    = string
  default = "user"
}
variable "openbsd-excluded-sets" {
  type    = string
  default = "-g* -x*"
}
variable "rc-firsttime-wait" {
  type    = string
  default = "60"
}

source "vmware-iso" "openbsd-packer" {
  version = "20"
  iso_url = "./empty.iso"
  iso_checksum = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  ssh_username = "user"
  ssh_password = "user"
  ssh_host = "${var.packer-ssh-host}"
  vnc_port_min = "${var.packer-vnc-port}"
  vnc_port_max = "${var.packer-vnc-port}"
  vnc_disable_password = "true"
  shutdown_command = "doas /sbin/shutdown -p now"
  keep_registered  = "false"
  skip_export = "false"
  headless = "true"
  format = "vmx"
  cpus = "4"
  memory = "4096"
  disk_adapter_type = "nvme"
  disk_size = "65535"
  network_adapter_type = "e1000e"
  usb = "true"
  guest_os_type = "arm-other-64"
  vmx_data = {
    # Nothing is working without EFI!!! ;-)
    "firmware" = "efi"
    "architecture" = "arm-other-64"
    # We need the USB stuff for packer to type text.
    "usb_xhci.present" = "TRUE"
    # We have to add the vmdk converted OpenBSD install image file,
    "nvme0.present" = "TRUE"
    "nvme0:1.fileName" = "${var.openbsd-install-img}"
    "nvme0:1.present" = "TRUE"
    # and make sure to boot from it.
    "bios.bootOrder" = "HDD"
    "bios.hddOrder" = "nvme0:1"
    # We are using a custom bridge network config,
    # because the download of the OpenBSD packages via NAT is extremely slow!!!
    "ethernet0.addresstype" = "static"
    "ethernet0.generatedaddressoffset" = "0"
    "ethernet0.bsdname" = "en0" # en0 on MacBooks is usually the Wifi interface
    "ethernet0.connectiontype" = "custom"
    "ethernet0.linkstatepropagation.enable" = "TRUE"
    "ethernet0.pcislotnumber" = "160"
    "ethernet0.present" = "TRUE"
    "ethernet0.vnet" = "vmnet3"
    "ethernet0.wakeonpcktrcv" = "FALSE"
    "ethernet0.address" = "00:0C:29:49:A7:51"
  }
  boot_wait = "25s"
  boot_command = [
    "install<return><wait2s>",
    "${var.openbsd-hostname}<return><wait2s>",
    "<return><wait2s>",
    "autoconf<return><wait5s>",
    "none<return><wait2s>",
    "done<return><wait2s>",
    "root<return><wait2s>",
    "root<return><wait2s>",
    "yes<return><wait2s>",
    "${var.openbsd-username}<return><wait2s>",
    "${var.openbsd-username}<return><wait2s>",
    "${var.openbsd-username}<return><wait2s>",
    "${var.openbsd-username}<return><wait2s>",
    "no<return><wait2s>",
    "<return><wait2s>",
    "?<return><wait2s>",
    "sd0<return><wait2s>",
    "whole<return><wait2s>",
    "a<return><wait5s>",
    "done<return><wait5s>",
    "disk<return><wait2s>",
    "no<return><wait2s>",
    "sd1<return><wait2s>",
    "a<return><wait2s>",
    "<return><wait2s>",
    "${var.openbsd-excluded-sets}<return><wait2s>",
    "done<return><wait2s>",
    "yes<return><wait30s>",
    "<return><wait2s>",
    "<return><wait30s>",
    "reboot<return><wait${var.rc-firsttime-wait}s>",
    "root<return><wait2s>",
    "root<return><wait3s>",
    "cp /etc/examples/doas.conf /etc/<return><wait2s>",
    "echo 'permit nopass :wheel as root' >> /etc/doas.conf<return><wait2s>",
    "exit<return><wait2s>",
  ]
}

build {
  sources = ["sources.vmware-iso.openbsd-packer"]
  # Upgrade the system to the latest patch level
  provisioner "shell" {
    expect_disconnect = "true"
    inline = [
      "doas syspatch",
      "doas shutdown -r now",
    ]
  }
  # After finishing the setup we copy the system log locally.
  provisioner "file" {
    pause_before     = "10s"
    direction   = "download"
    source      = "/var/log/messages"
    destination = "./log/"
  }
  # After finishing the setup we copy the daemon log locally.
  provisioner "file" {
    direction   = "download"
    source      = "/var/log/daemon"
    destination = "./log/"
  }
  # We have to make sure that the doas rights of the user are restricted again.
  provisioner "shell" {
    inline = [
      "doas sed -i 's|permit nopass :wheel as root|permit nopass :wheel as root cmd /sbin/shutdown|g' /etc/doas.conf"
    ]
  }
}
