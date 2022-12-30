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
user=""
errorfile=".error_vm_storagepool.txt"

echo "Anzahl übergebene Parameter: '$#'"
if [ $# -gt 0 ]; then 
	echo "Erster Parameter '$1' wird als user-id verwendet"
	user=$1
else
	user="sandro"   # standardwert
	echo "standardwert '${user}' wird für user-id verwendet"
fi
#echo "user-id ist: '${user}'"

homepath="/home/${user}"
storagedir="Downloads"
storagepath="${homepath}/${storagedir}"


### check storagepath:
if [ -d "${storagepath}" ]; then
	echo "storagepath: '${storagepath}'"
else
	echo "gewünschter storagepath '${storagepath}' nicht vorhanden"
	echo "home-verzeichnis für user '${user}' inkl. '${storagedir}'-verzeichnis bitte anlegen (lassen) oder anderen user verwenden"
	echo "Programm wird beendet"
	exit 1
fi


### ensure hypervisor supports directory-based storage pools:
supportstoragetype=$(virsh pool-capabilities | grep "'dir' supported='yes'")   # wenn ja, ausgabe: <pool type='dir' supported='yes'>
#echo  ${supportstoragetype}
if [[ "${supportstoragetype}" != *"yes"* ]]; then
	echo "directory-based storage pools not supported, exit program." | tee "/home/${user}/.error_vm_storagepool.txt"
	exit 1
fi


### create storage pool:
echo "pool-define-as..."
nvmessdpath="/dev/nvme0n1p3"

if [ -d ${nvmessdpath} ]; then
	virsh pool-define-as ${storagedir} dir --source-dev ${nvmessdpath} --target "${storagepath}"
else
	echo "source-dev path '${nvmessdpath}'" | tee -a "/home/${user}/${errorfile}"
	echo "programm wird beendet"
	exit 1
fi

echo "pool-build..."
virsh pool-build ${storagedir}

if [[ $(virsh pool-list --all | grep ${storagedir}) != *"${storagedir}"*  ]]; then
	echo "storage pool '${storagedir}' wurde nicht angelegt" | tee -a "/home/${user}/${errorfile}"
else
	echo "pool-start..."
	virsh pool-start ${storagedir}

	echo "pool-autostart..."
	virsh pool-autostart ${storagedir}
fi

echo "pool-list:"
virsh pool-list --all

