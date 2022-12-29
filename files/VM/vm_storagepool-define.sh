#!/bin/bash

###
### create storage pool for user '${user}': /home/user/Downloads
### parameter: user (default: 'sandro')

#path=$(pwd)
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
fsstoragedir="Downloads"
fsstoragepath="${homepath}/${fsstoragedir}"
if [ -d "${fsstoragepath}" ]; then
	echo "fsstoragepath: '${fsstoragepath}'"
else
	echo "gewünschter fsstoragepath '${fsstoragepath}' nicht vorhanden"
	echo "home-verzeichnis für user '${user}' inkl. '${fsstoragedir}'-verzeichnis bitte anlegen (lassen) oder anderen user verwenden"
	echo "Programm wird beendet"
	exit 1
fi


########################################
### create filesystem-based storage pool
########################################
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_virtualization/managing-storage-for-virtual-machines_configuring-and-managing-virtualization#creating-filesystem-based-storage-pools-using-the-cli_assembly_managing-virtual-machine-storage-pools-using-the-cli
# https://www.tecmint.com/manage-kvm-storage-volumes-and-pools/

### ensure hypervisor supports filesystem-based storage pools:
supportfsstorage=$(virsh pool-capabilities | grep "'fs' supported='yes'")   # wenn ja, ausgabe: <pool type='fs' supported='yes'>
#echo  ${supportfsstorage}
if [[ "${supportfsstorage}" != *"yes"* ]]; then
	echo "filesystem-based storage pools not supported, exit program."
	echo "filesystem-based storage pools not supported, exit program." >> "/home/${user}/.error_vm_storagepool.txt"
	exit 1
fi


### create storage pool:
echo "pool-define-as..."
virsh pool-define-as ${fsstoragedir} fs --source-dev /dev/nvme0n1p3 --target "${fsstoragepath}"

echo "pool-build..."
virsh pool-build ${fsstoragedir}

if [[ $(virsh pool-list --all | grep ${fsstoragedir}) != *"${fsstoragedir}"*  ]]; then
	echo "storage pool '${fsstoragedir}' wurde nicht angelegt"
	echo "storage pool '${fsstoragedir}' wurde nicht angelegt" >> "/home/${user}/${errorfile}"
else
	echo "pool-start..."
	virsh pool-start ${fsstoragedir}

	echo "pool-autostart..."
	virsh pool-autostart ${fsstoragedir}
fi

virsh pool-list --al

