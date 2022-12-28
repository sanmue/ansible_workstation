#!/bin/bash

#path=$(pwd)

######################
### redefine snapshots
######################
snapshotfileList=$(ls snapshotdump_*)
#echo "${snapshotfileList}"

echo -e "\nredefine snapshots:"
for snapshotfile in ${snapshotfileList}; do
	#echo "- snapshotfile: ${snapshotfile}"
	domain=$(echo "${snapshotfile}" | cut -d _ -f 2)
	echo "- domain: ${domain}"

	# snapshot-create --redefine
	virsh snapshot-create "${domain}" --xmlfile "${snapshotfile}" --redefine
done


########################
### set current snapshot
########################
snapshotcurrentfileList=$(ls snapshotcurrent_*)
#echo "${snapshotcurrentfileList}"

echo -e "\nset current snapshot:"
for snapshotcurrentfile in ${snapshotcurrentfileList}; do
	#echo "- snapshotcurrentfile: ${snapshotcurrentfile}"
	#domain=$(echo "${snapshotcurrentfile}" | cut -d _ -f 2 | cut -d . -f 1)   
															# Problem bei domain z.B. 'ubuntu22.04' wegen '." in Domain-Name
	domain=$(echo "${snapshotcurrentfile}" | cut -d _ -f 2 | awk '{print substr($0,1,length-4)}')   # letzte 4 Zeichen abschneiden (.txt)
	echo -e "\n- domain: ${domain}"
	snapshotcurrent=$(cat "${snapshotcurrentfile}")
	#echo "- snapshotcurrent: ${snapshotcurrent}"

	virsh snapshot-current "${domain}" "${snapshotcurrent}"
done

