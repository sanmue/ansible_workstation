#!/usr/bin/env bash

# set -x # enable debug mode

# ### -------------------------------------------------------------------------
# Description
# * using snapper-rollback (AUR) to rollback to a specified snapshot ID
# * only if:
#   - EndeavourOS with 'systemd-boot' Bootloader
#   - snapper + btrfs subvolumes
# ---
# Parameter
# * parameter 1 (required): snapshot ID to rollback to
# ---
# Example
# * enter in terminal: 'rollback 8'
# ### -------------------------------------------------------------------------
snapshotsSubvolPath="/.snapshots"
efiPartitionPath="/efi"
efiPartition_targetPath="${efiPartitionPath}/" # destination for kernel and initramfs,... matching the snapshot ID to rollback to
bootFolderPath="/boot"
bootFolder_targetPath="${bootFolderPath}/" # amd-/intel-ucode.img

efiBackupSourcePath="/.efibackup"
efiBackupSourcePath_pre="${efiBackupSourcePath}/pre/"
bootBackupSourcePath="/.bootbackup"
bootBackupSourcePath_pre="${bootBackupSourcePath}/pre/"

if [ "$#" -eq 1 ] && [ "${1}" -ge 1 ]; then # if exactly 1 parameter is passed and is an integer >= 1
    snapshotID="${1}" # Parameter 1: snapshot ID to rollback to
    snapshotFolder="${snapshotsSubvolPath}/${snapshotID}" # source path snapshot ID to rollback to
else
    echo -e "\e[0;31mParameter error: pass exactly one parameter (snapshot ID) which has to be an integer value >= 1\e[39m"
    echo -e "Example: 'rollback 8'\nTo find the snapshot ID execute 'sudo snapper list'"
    exit 1
fi

if [[ $(command -v snapper-rollback) ]]; then
    echo "Installing 'rsync' if not available..."
    sudo pacman -S --needed --noconfirm rsync # ensure rsync is installed

    mode="test"
    read -rp "Do you want to just test or execute the rollback? ('e' = execute, other input = test): " mode
    rollbackParameter=""
    rsyncParameter=""
    if [ "${mode}" = "e" ]; then
        sudo snapper-rollback "${snapshotID}"

        echo -e "\nCopy bootbackup from snapshot ${snapshotID} to '${bootFolder_targetPath}'..."
        sudo rsync -aPhEv --delete "${snapshotFolder}${bootBackupSourcePath_pre}" "${bootFolder_targetPath}"

        echo -e "\nCopy efibackup from snapshot ${snapshotID} to '${efiPartition_targetPath}'..."
        sudo rsync -aPhEv --delete "${snapshotFolder}${efiBackupSourcePath_pre}" "${efiPartition_targetPath}"
    else
        rollbackParameter="--dry-run"
        rsyncParameter="--dry-run"

        echo -e "\nTESTING rollback, this is gonna be just a ${rollbackParameter}..."
        sudo snapper-rollback "${rollbackParameter}" "${snapshotID}"

        echo -e "\nCopy bootbackup from snapshot ${snapshotID} to '${bootFolder_targetPath}' ${rsyncParameter}..."
        sudo rsync -aPhEv --delete "${rsyncParameter}" "${snapshotFolder}" "${efiPartition_targetPath}"

        echo -e "\nCopy efibackup from snapshot ${snapshotID} to '${efiPartition_targetPath}' ${rsyncParameter}..."
        sudo rsync -aPhEv --delete "${rsyncParameter}" "${snapshotFolder}" "${efiPartition_targetPath}"
    fi
else
    echo -e "\e[0;31m'snapper-rollback' not available, rollback not possible.\e[39m"
    exit
fi
