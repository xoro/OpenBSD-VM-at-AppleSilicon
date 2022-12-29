packer {
  required_version = ">= 1.8.0"
  required_plugins {
    vmware = {
      version = "= 1.0.7"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

variable "install-img" {
  type    = string
  default = ""
}
source "vmware-iso" "openbsd-packer" {
  version = "20"
  iso_url = "./empty.iso"
  iso_checksum = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  ssh_username = "user"
  ssh_password = "user"
  ssh_host = "openbsd-packer"
  vnc_port_min = "5987"
  vnc_port_max = "5987"
  vnc_disable_password = "true"
  shutdown_command = "doas /sbin/shutdown -p now"
  keep_registered  = "false"
  skip_export = "false"
  headless = "true"
  format = "vmx"
  cpus = "4"
  memory = "4096"
  disk_adapter_type = "nvme"
  disk_size = "64000"
  network_adapter_type = "vmxnet3"
  guest_os_type = "arm-other-64"
  vmx_data = {
    # Nothing is working without EFI!!! ;-)
    "firmware" = "efi"
    # We need the USB stuff for packer to type text.
    "usb.present" = "TRUE"
    "ehci.present" = "TRUE"
    "usb_xhci.present" = "TRUE"
    # We have to add the vmdk converted OpenBSD install image file,
    "nvme0.present" = "TRUE"
    "nvme0:1.fileName" = "${var.install-img}"
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
  boot_wait = "20s"
  boot_command = [
    "install<return><wait1s>",
    "openbsd-packer<return><wait1s>",
    "<return><wait1s>",
    "autoconf<return><wait10s>",
    "none<return><wait1s>",
    "done<return><wait1s>",
    "root<return><wait1s>",
    "root<return><wait1s>",
    "yes<return><wait1s>",
    "user<return><wait1s>",
    "user<return><wait1s>",
    "user<return><wait1s>",
    "user<return><wait1s>",
    "no<return><wait1s>",
    "<return><wait1s>",
    "?<return><wait1s>",
    "sd0<return><wait1s>",
    "whole<return><wait1s>",
    "a<return><wait5s>",
    "done<return><wait5s>",
    "disk<return><wait1s>",
    "no<return><wait1s>",
    "sd1<return><wait1s>",
    "a<return><wait1s>",
    "<return><wait1s>",
    "-g* -x*<return><wait1s>",
    "done<return><wait1s>",
    "yes<return><wait30s>",
    "<return><wait1s>",
    "<return><wait30s>",
    "reboot<return><wait60s>",
    "root<return><wait1s>",
    "root<return><wait1s>",
    "cp /etc/examples/doas.conf /etc/<return><wait1s>",
    "echo 'permit nopass :wheel as root' >> /etc/doas.conf<return><wait1s>",
    "exit<return><wait1s>",
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
    pause_before     = "20s"
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