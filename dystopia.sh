#!/bin/bash

# =============== CONFIGURATION ===============
# Edit these variables as needed

# Base directory containing all files
WORK_DIR="$HOME/Desktop/dystopia"

# Virtual machine files
BASE_IMAGE="alpine_base.raw"  # Base installation image
PRIVATE_IMAGE="private.qcow2" # Differential private image
EFI_BIOS="QEMU_EFI.fd"        # EFI bios file
ALPINE_ISO="alpine.iso"        # Alpine installation ISO

# Shared folder settings
SHARED_FOLDER_NAME="shared"   # Name of shared folder (inside WORK_DIR)
SHARED_MOUNT_POINT="/shared"  # Mount point inside VM

# VM resources
CPU_CORES=4
MEMORY_MB=3000

# Network settings
SSH_PORT=2222                 # Host port forwarded to VM's SSH
SSH_USER="root"               # Default Alpine username

# =============== RUNTIME ===============
# Don't edit below unless you know what you're doing

echo "[INFO] This script runs a qemu vm of alpine linux"
echo "[INFO] To install, change the INSTALL_MODE variable and follow README.md"
echo "[INFO] To reset the VM to its initial state AFTER the installation, delete private.qcow2"
echo "[INIT] Starting checks..."

# Create necessary directories and files
echo "[CHECK] .../dystopia/shared directory"
mkdir -p "$WORK_DIR/$SHARED_FOLDER_NAME"

# Check if private image exists, create if needed
echo "[CHECK] private.qcow2"
if [ ! -f "$WORK_DIR/$PRIVATE_IMAGE" ]; then
    if [ ! -f "$WORK_DIR/$BASE_IMAGE" ]; then
        echo "[ERROR] Base image $BASE_IMAGE not found!"
        echo "Please run the installation first or check your configuration."
        exit 1
    fi
    echo "[CREATE] New private differential image..."
    qemu-img create -f qcow2 \
      -b "$WORK_DIR/$BASE_IMAGE" \
      -F raw \
      "$WORK_DIR/$PRIVATE_IMAGE"
fi

# Check for EFI BIOS file
if [ ! -f "$WORK_DIR/$EFI_BIOS" ]; then
    echo "[ERROR] EFI BIOS file $EFI_BIOS not found in $WORK_DIR!"
    exit 1
fi

# Determine if we're running in installation mode
INSTALL_MODE=0
if [ ! -f "$WORK_DIR/$BASE_IMAGE" ]; then
    if [ ! -f "$WORK_DIR/$ALPINE_ISO" ]; then
        echo "[ERROR] Alpine ISO $ALPINE_ISO not found for installation!"
        exit 1
    fi
    INSTALL_MODE=1
fi

echo "[INIT] Checks are finished"

# Run QEMU with appropriate parameters
if [ $INSTALL_MODE -eq 1 ]; then
    echo "[QEMU] Starting installation process..."
    qemu-system-aarch64 \
       -monitor stdio \
       -M virt,highmem=off \
       -accel hvf \
       -cpu host \
       -smp $CPU_CORES \
       -m $MEMORY_MB \
       -bios "$WORK_DIR/$EFI_BIOS" \
       -device virtio-gpu-pci \
       -display default,show-cursor=on \
       -device qemu-xhci \
       -device usb-kbd \
       -device usb-tablet \
       -device intel-hda \
       -device hda-duplex \
       -drive file="$WORK_DIR/$BASE_IMAGE",format=raw,if=virtio,cache=writethrough \
       -netdev user,id=net0,hostfwd=tcp::$SSH_PORT-:22 \
       -device virtio-net-pci,netdev=net0 \
       -cdrom "$WORK_DIR/$ALPINE_ISO"
else
    echo "[QEMU] Starting virtual machine..."
    qemu-system-aarch64 \
      -M virt,highmem=off \
      -accel hvf \
      -cpu host \
      -smp $CPU_CORES \
      -m $MEMORY_MB \
      -bios "$WORK_DIR/$EFI_BIOS" \
      -drive file="$WORK_DIR/$PRIVATE_IMAGE",format=qcow2,if=virtio,cache=writethrough \
      -netdev user,id=net0,hostfwd=tcp::$SSH_PORT-:22 \
      -device virtio-net-pci,netdev=net0 \
      -display none \
      -monitor none \
      -serial none \
      -fsdev local,id=shared_dev,path="$WORK_DIR/$SHARED_FOLDER_NAME",security_model=none \
      -device virtio-9p-pci,fsdev=shared_dev,mount_tag=shared_folder &
    
    # Get QEMU's PID
    QEMU_PID=$!
    
    # Wait a moment for VM to initialize
    sleep 15
    
    # Show connection info
    echo "[INFO] dystopia is up"
    echo "[INFO] To connect via SSH:"
    echo "    ssh -p $SSH_PORT $SSH_USER@localhost"
    echo "[INFO] Shared folder available at:"
    echo "    $SHARED_MOUNT_POINT"

    # Wait for QEMU to finish
    wait $QEMU_PID

    echo "[QEMU] VM if powered-off"
fi