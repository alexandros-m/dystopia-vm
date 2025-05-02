# dystopia

## Setup Instructions

### 1. Download Required Files

```bash
# Alpine Linux ISO
wget https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/aarch64/alpine-virt-3.21.3-aarch64.iso -O alpine.iso

# QEMU EFI firmware (download and extract manually)
# From: https://gist.github.com/theboreddev/5f79f86a0f163e4a1f9df919da5eea20
```

### 2. Create Working Directory

```
mkdir -p ~/Desktop/dystopia
mv alpine.iso ~/Desktop/dystopia/
# Place QEMU_EFI.fd in the same directory
```

### 3. Create Base Disk Image

```bash
cd ~/Desktop/dystopia
qemu-img create -f raw alpine-base.raw 1G
```

## Installation

### 1. Run Installation

```bash
qemu-system-aarch64 \
   -monitor stdio \
   -M virt,highmem=off \
   -accel hvf \
   -cpu host \
   -smp 4 \
   -m 3000 \
   -bios QEMU_EFI.fd \
   -device virtio-gpu-pci \
   -display default,show-cursor=on \
   -device qemu-xhci \
   -device usb-kbd \
   -device usb-tablet \
   -device intel-hda \
   -device hda-duplex \
   -drive file=alpine-base.raw,format=raw,if=virtio,cache=writethrough \
   -netdev user,id=net0,hostfwd=tcp::2222-:22 \
   -device virtio-net-pci,netdev=net0 \
   -cdrom alpine.iso
```

During installation:

1. Run `alpine-setup`

2. Select `vda` as disk

3. Select `sys` as installation mode

### 2. Post-Installation Boot

```bash
qemu-system-aarch64 \
   -M virt,highmem=off \
   -accel hvf \
   -cpu host \
   -smp 4 \
   -m 3000 \
   -bios QEMU_EFI.fd \
   -drive file=alpine-base.raw,format=raw,if=virtio,cache=writethrough \
   -netdev user,id=net0,hostfwd=tcp::2222-:22 \
   -device virtio-net-pci,netdev=net0 \
   -display none \
   -monitor none \
   -serial none
```

Access via SSH:

```bash
ssh -p 2222 root@localhost
```

## Shared Folder Setup

1. Create mount script at `/etc/local.d/9pfs.start`:

```bash
#!/bin/sh

# Load 9p modules and mount the shared_folder tag

mkdir -p /shared
modprobe 9pnet_virtio
modprobe 9p

mount -t 9p \
  -o trans=virtio,version=9p2000.L \
  shared_folder /shared
```

2. Make script executable:

```bash
chmod +x /etc/local.d/9pfs.start
```

3. Create shared folder on host:

```bash
mkdir -p ~/Desktop/dystopia/shared
```

4. Boot with shared folder support:

```bash
qemu-system-aarch64 \
   -M virt,highmem=off \
   -accel hvf \
   -cpu host \
   -smp 4 \
   -m 3000 \
   -bios QEMU_EFI.fd \
   -drive file=alpine_base.raw,format=raw,if=virtio,cache=writethrough \
   -netdev user,id=net0,hostfwd=tcp::2222-:22 \
   -device virtio-net-pci,netdev=net0 \
   -display none \
   -monitor none \
   -serial none \
   -fsdev local,id=shared_dev,path=/Users/alex/Desktop/dystopia/shared,security_model=none \
   -device virtio-9p-pci,fsdev=shared_dev,mount_tag=shared_folder
```

## Create Private Instance

1. Create differential image:

```bash
qemu-img create -f qcow2 \
  -b alpine_base.raw \
  -F raw \
  private.qcow2
```

2. Final boot command:

```bash
qemu-system-aarch64 \
  -M virt,highmem=off \
  -accel hvf \
  -cpu host \
  -smp 4 \
  -m 3000 \
  -bios QEMU_EFI.fd \
  -drive file=private.qcow2,format=qcow2,if=virtio,cache=writethrough \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -display none \
  -monitor none \
  -serial none \
  -fsdev local,id=shared_dev,path=/Users/alex/Desktop/dystopia/shared,security_model=none \
  -device virtio-9p-pci,fsdev=shared_dev,mount_tag=shared_folder
```

## Notes

- Replace `/Users/alex/Desktop/dystopia` with your actual path

- The base image (`alpine-base.raw`) can be kept as a template

- Each private instance (`private.qcow2`) will store only differences from the base
