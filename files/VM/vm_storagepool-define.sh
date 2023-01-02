#!/bin/bash

### --------------------------------------------------------------------
### create storage pool for user (directory-based, /home/user/Downloads)
#   - parameter: user (default: 'sandro')
#   - Quellen:
#		- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_virtualization/managing-storage-for-virtual-machines_configuring-and-managing-virtualization#creating-directory-based-storage-pools-using-the-cli_assembly_managing-virtual-machine-storage-pools-using-the-cli
# 		- https://www.tecmint.com/manage-kvm-storage-volumes-and-pools/
### --------------------------------------------------------------------


### parameter, variablen:
#currentpath=$(pwd)
#user=$(whoami)
user="sandro"    # Standardwert, wird ggf. durch übergebenen Parameter geändert.
errorfile=".error_vm_storagepool.txt"

echo "Anzahl übergebene Parameter: '$#'"
if [ $# -gt 0 ]; then 
	echo "Erster Parameter '$1' wird als User-Id verwendet"
	user=$1
else
	echo "Standardwert '${user}' wird als User-Id verwendet"
fi


### check storagepath:
homepath="/home/${user}"
storagedir="Downloads"
storagepath="${homepath}/${storagedir}"

if [ -d "${storagepath}" ]; then
	echo "Storagepath: '${storagepath}'"
else
	echo "Gewünschter Storagepath '${storagepath}' nicht vorhanden."
	echo "Home-Verzeichnis für User '${user}' inkl. '${storagedir}'-Verzeichnis bitte anlegen (lassen) oder anderen User verwenden."
	echo "Programm wird beendet."
	exit 1
fi


### ensure hypervisor supports directory-based storage pools:
supportstoragetype=$(virsh pool-capabilities | grep "'dir' supported='yes'")   # wenn ja, ausgabe: <pool type='dir' supported='yes'>
#echo  ${supportstoragetype}
if [[ "${supportstoragetype}" != *"yes"* ]]; then
	echo "Directory-based storage pools not supported, exit program." | tee "/home/${user}/.error_vm_storagepool.txt"
	exit 1
fi


### create storage pool:
echo "pool-define-as..."
osssddevice="nvme0n1p"   # Anfang Device-Bezeichnung bei Nvme-SSDs
#nvmessdpath=$(ls /dev/${osssddevice}? | tail -n 1)   # z.B.: /dev/nvme0n1p4"; davon ausgehend, dass es nicht mehr als 9 Partitionen gibt und der letzte Treffer die OS-Partition ist, auf die der Storage Pool soll
nvmessdpath=$(find /dev/ -name "${osssddevice}?" | tail -n 1)   # Alternative mit find

#if [[ $(ls /dev/ | grep ${nvmessdpath}) == *"${nvmessdpath}"* ]]; then
if [ -n "${nvmessdpath}" ]; then   # -n: if string length is not zero
	virsh pool-define-as ${storagedir} dir --source-dev "${nvmessdpath}" --target "${storagepath}"
else
	#echo "source-dev path '${nvmessdpath}' nicht vorhanden." | tee -a "/home/${user}/${errorfile}"
	echo "Nvme-SSD osssddevice ('${osssddevice}x') nicht vorhanden." | tee -a "/home/${user}/${errorfile}"
	echo "Programm wird beendet."
	exit 1
fi

echo "pool-build..."
virsh pool-build ${storagedir}

if [[ $(virsh pool-list --all | grep ${storagedir}) != *"${storagedir}"*  ]]; then   # einfache Prüfung, ggf. false Positives
	echo "Storage pool '${storagedir}' wurde nicht angelegt." | tee -a "/home/${user}/${errorfile}"
else
	echo "pool-start..."
	virsh pool-start ${storagedir}

	echo "pool-autostart..."
	virsh pool-autostart ${storagedir}
fi

echo "pool-list:"
virsh pool-list --all

