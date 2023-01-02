#!/bin/bash

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
			existingDomainSnapshotList=$(virsh snapshot-list "${domain}" --name --topological)

			#if [[ "${snapshot}" == *"${existingDomainSnapshotList}"* ]]; then ...   # einfache Abfrage, ggf. false positives
			#if [[ "${snapshot}" =~ ${existingDomainSnapshotList} ]]; then ...

			
			for existingSnapshot in $existingDomainSnapshotList; do
				found=''
				if [ "${snapshot}" != "${existingSnapshot}" ]; then
					found='nein'
				else
					found='ja'
					echo "Snapshot '${snapshot}' für domain '${domain}' existiert bereits."
					break
				fi
			done

			echo "found: ${found}"
			if [ "${found}" = 'nein' ]; then
				echo "found innerhalb if: ${found}"
				virsh snapshot-create "${domain}" --xmlfile "${snapshotdumpfile}" --redefine
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

	virsh snapshot-current "${domain}" "${snapshotcurrent}"
done

