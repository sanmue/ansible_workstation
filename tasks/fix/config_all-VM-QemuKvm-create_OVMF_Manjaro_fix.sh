#!/usr/bin/env bash

#set -x   # enable debug mode

### für Manjaro/Archlinux: Bei Neuerstellung QEMU/KVM-VMs aus Ubuntu
### Stand: 02/2023, VMs aus Ubuntu 22.04
# - unter Ubuntu zeigen die Pfade für UEFI/Secureboot auf einen anderen Pfad
# - erstelle daher Symlinks für entsprechende Pfade bei Manjaro

ovmfPath="/usr/share/OVMF"
ovmf64Path="${ovmfPath}/x64"
edk264Path="/usr/share/edk2/x64"

if [ -e "${ovmf64Path}" ]; then
	ovmf64List=$(sudo ls "${ovmf64Path}")
else
	echo "Verzeichnis '${ovmf64Path}' existiert nicht."
	echo "Symlinks können nicht angelegt werden. Breche ab."
	exit 1
fi

if [ ! -e "${edk264Path}" ]; then
	echo "Zielverzeichnis '${edk264Path}' für Symlinks nicht vorhanden. Breche ab."
	exit 1
fi

for listItem in ${ovmf64List}; do
	if [ ! -e "${ovmfPath}/${listItem}" ]; then
		#echo "Erstelle Symlink für ${listItem}..."
		sudo ln -s "${edk264Path}/${listItem}" "${ovmfPath}/${listItem}"
	#else
		#echo "'${ovmfPath}/${listItem}' bereits vorhanden"
	fi	
done

