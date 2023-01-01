#!/bin/bash

#path=$(pwd)

######################
### redefine snapshots
######################
snapshotfileList=$(ls snapshotdump_*)
#echo "${snapshotfileList}"

#echo -e "\nredefine snapshots:"
#for snapshotfile in ${snapshotfileList}; do
#	#echo "- snapshotfile: ${snapshotfile}"          # z.B. snapshotdump_ubuntu22.04_init.xml
#	domain=$(echo "${snapshotfile}" | cut -d _ -f 2) # 2. Teilstück:     ubuntu22.04
#	echo "- domain: ${domain}"
#
#	# snapshot-create --redefine
#	virsh snapshot-create "${domain}" --xmlfile "${snapshotfile}" --redefine
#done

snapshotfileList=$(ls snapshotList_*)
#echo "${snapshotfileList}"

echo -e "\nredefine snapshots:"
for snapshotfile in ${snapshotfileList}; do
	#echo "- snapshotfile: ${snapshotfile}"          # z.B. snapshotList_ubuntu22.04.xml
	domain=$(echo "${snapshotfile}" | cut -d _ -f 2 | awk '{print substr($0,1,length-4)}')   # -> 'ubuntu22.04' (2. Teilstück + letzte 4 Zeichen abschneiden (.txt))
	echo "- domain: ${domain}"

	domainSnapshotList=$(cat "${snapshotfile}")
	if [ -n "${domainSnapshotList}" ]; then
		for snapshot in ${domainSnapshotList}; do echo
			snapshotdumpfile="snapshotdump_${domain}_${snapshot}.xml"
			
			# snapshot-create --redefine
			virsh snapshot-create "${domain}" --xmlfile "${snapshotdumpfile}" --redefine
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

