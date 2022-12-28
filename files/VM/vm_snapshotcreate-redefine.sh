#!/bin/bash

#path=$(pwd)

######################
### redefine snapshots
######################
snapshotfileList=$(ls snapshotdump_*)
#echo "${snapshotfileList}"

for snapshotfile in ${snapshotfileList}; do
	#echo "- snapshotfile: ${snapshotfile}"
	domain=$(echo "${snapshotfile}" | cut -d _ -f 2)
	#echo "- domain: ${domain}"
	#snapshot=$(echo "${snapshotfile}" | cut -d _ -f 3 | cut -d . -f 1)
	#echo "- snapshot: ${snapshot}"

	# snapshot-create --redefine
	virsh snapshot-create "${domain}" -xmlfile "${snapshotfile}" --redefine
done


#########################
### set current snapshots
#########################
snapshotcurrentfileList=$(ls snapshotcurrent_*)
#echo "${snapshotcurrentfileList}"

for snapshotcurrentfile in ${snapshotcurrentfileList}; do
	#echo "- snapshotcurrentfile: ${snapshotcurrentfile}"
	domain=$(echo "${snapshotcurrentfile}" | cut -d _ -f 2 | cut -d . -f 1)
	#echo "- domain: ${domain} "
	snapshotcurrent=$(cat "${snapshotcurrentfile}")
	#echo "- snapshotcurrent: ${snapshotcurrent}"

	virsh snapshot-current "${domain}" "${snapshotcurrent}"
done

