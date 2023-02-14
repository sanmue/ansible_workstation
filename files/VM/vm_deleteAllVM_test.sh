#!/bin/bash

### ############
### Lösche VMs incl.:
#   - storage pools (ausser 'default')
#   - networks (ausser 'default')
#   - snapshots
### ############


### delete storage pools:
echo "Storage Pools werden gelöscht, Inhalte jedoch NICHT"
sudo virsh pool-list --all
storagepoolList=$(sudo virsh pool-list --all --name)
if [ -n "${storagepoolList}" ]; then
	#echo -e "- storagepoolList:\n${storagepoolList}"

	for storagepool in ${storagepoolList}; do
		if [ "${storagepool}" == "default" ]; then
			echo "- 'default' storage pool wird nicht gelöscht."
		else
			storagepoolstatus=$(sudo virsh pool-info "${storagepool}" | grep State | cut -d : -f 2 | xargs)
			if [ "${storagepoolstatus}" == "running" ]; then
				echo "- pool-destroy..."
				sudo virsh pool-destroy "${storagepool}"   # nur bei deaktivierten storage pools
			fi
			
			#echo "pool-delete..."
			#sudo virsh pool-delete "${storagepool}"   ### funktioniert nur, wenn Daten im Pool gelöscht sind
			
			echo "- pool-undefine..."
			sudo virsh pool-undefine "${storagepool}"
		fi
	done	
else
	echo "storagepoolList ist leer"
fi

echo "- storagepoolList neu:"
sudo virsh pool-list --all


### delete networks:
echo -e "\nNetworks werden gelöscht"
sudo virsh net-list --all
networkList=$(sudo virsh net-list --all --name)
if [ -n "${networkList}" ]; then
	#echo -e "- networkList:\n${networkList}"

	for network in ${networkList}; do
		if [ "${network}" == "default" ]; then
			echo "- 'default' Network wird nicht gelöscht."
		else
			netstatus=$(sudo virsh net-info "${network}" | grep Active | cut -d : -f 2 | xargs)
			if [ "${netstatus}" == "yes" ]; then
				echo "- net-destroy..."
				sudo virsh net-destroy "${network}"
			fi
			
			echo "- net-undefine..."
			sudo virsh net-undefine "${network}"
		fi
	done	
else
	echo "networkList ist leer."
fi

echo "- networkList neu:"
sudo virsh net-list --all


### delete Snapshots + VMs:
echo -e "\nVMs werden gelöscht"
sudo virsh list --all
domainList=$(sudo virsh list --all --name)
if [ -n "${domainList}" ]; then
	#echo -e "- domainList:\n${domainList}"

	for domain in ${domainList}; do
		domainstatus=$(sudo virsh dominfo "${domain}" | grep State | cut -d : -f 2 | xargs)
		#case "${domainstatus}" in	
		#	"paused")
		#		sudo virsh resume "${domain}" && sudo virsh shutdown "${domain}"
		#		;;
	
		#	"running")
		#		sudo virsh shutdown "${domain}"
		#		;;
		#esac
		
		#---'shutdown' VMs
		if [ "${domainstatus}" != "shut off" ]; then
			echo "- destroy..."
			sudo virsh destroy "${domain}" --graceful
		fi

### delete snapshots
		snapshotList=$(sudo virsh snapshot-list "${domain}" --name)
		if [ -n "${snapshotList}" ]; then
			echo "- delete snapshots, Domain '${domain}'..."
			for snapshot in ${snapshotList}; do
				sudo virsh snapshot-delete "${domain}" --snapshotname "${snapshot}"
			done
		else
			echo "Domain '${domain}' hat keine Snapshots."	
		fi
### delete VMs
		echo "- undefine..."
		sudo virsh undefine "${domain}"

		echo
	done	
else
	echo "domainList ist leer."
fi

echo "- domainList neu:"
sudo virsh list --all


### delete vmflag-file (ansible) for VM-Stuff
vmflagfile="$HOME/.vm_qemu-kvm_created"

if [ -e "${vmflagfile}" ]; then
	echo -e "\nDeleting file '${vmflagfile}'"
	rm -f "${vmflagfile}"
fi
