#!/usr/bin/env bash

#set -x   # enable debug mode

#path=$(pwd)

######################
### redefine snapshots
######################
snapshotfileList=$(ls snapshotdump_*)
#echo "${snapshotfileList}"

snapshotfileList=$(ls snapshotList_*)
#echo "${snapshotfileList}"

echo -e "\nredefine snapshots:"
for snapshotfile in ${snapshotfileList}; do
	#echo "- snapshotfile: ${snapshotfile}"          # z.B. snapshotList_ubuntu22.04.xml
	domain=$(echo "${snapshotfile}" | cut -d _ -f 2 | awk '{print substr($0,1,length-4)}')   # -> 'ubuntu22.04' (2. Teilstück + letzte 4 Zeichen abschneiden (.txt))
	echo "- domain: ${domain}"

	domainSnapshotfileList=$(cat "${snapshotfile}")
	if [ -n "${domainSnapshotfileList}" ]; then
		for snapshot in ${domainSnapshotfileList}; do echo
			snapshotdumpfile="snapshotdump_${domain}_${snapshot}.xml"
			
			# snapshot-create --redefine
			existingDomainSnapshotList=$(sudo virsh snapshot-list "${domain}" --name --topological)
			found='nein'   # Init mit Standardwert
			for existingSnapshot in $existingDomainSnapshotList; do   	# zuerst prüfen, ob der Snapshot nicht innerhalb eines vorhergehendne Laufs schon existiert
																		# ansonsten würde wieder neu definiert. Funktioniert, gefällt aber nicht
				if [ "${snapshot}" == "${existingSnapshot}" ]; then
					found='ja'
					echo "Snapshot '${snapshot}' für domain '${domain}' existiert bereits."
					break
				fi
			done

			if [ "${found}" == 'nein' ]; then
				sudo virsh snapshot-create "${domain}" --xmlfile "${snapshotdumpfile}" --redefine
			fi
		done
	else
		echo "snapshotfile '${snapshotfile}' enthält keine Einträge."
	fi
done


########################
### set current snapshot
########################
snapshotcurrentfileList=$(ls snapshotcurrent_*)
#echo "${snapshotcurrentfileList}"

echo -e "\nset current snapshot:"
for snapshotcurrentfile in ${snapshotcurrentfileList}; do
	#echo "- snapshotcurrentfile: ${snapshotcurrentfile}"   # snapshotcurrent_ubuntu22.04.txt
	#domain=$(echo "${snapshotcurrentfile}" | cut -d _ -f 2 | cut -d . -f 1)   
															# Problem bei domain z.B. 'ubuntu22.04' wegen '." in Domain-Name
	domain=$(echo "${snapshotcurrentfile}" | cut -d _ -f 2 | awk '{print substr($0,1,length-4)}')   # letzte 4 Zeichen abschneiden (.txt)
	echo -e "\n- domain: ${domain}"
	snapshotcurrent=$(cat "${snapshotcurrentfile}")
	#echo "- snapshotcurrent: ${snapshotcurrent}"

	sudo virsh snapshot-current "${domain}" "${snapshotcurrent}"   # keine Überprüfung, ob bereits in einem vorhergehendem Durchlauf gesetzt wurde; wird ggf. einfach nochmal gesetzt
done

