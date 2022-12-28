#!/bin/bash

exportPath=$(pwd)

# net-dumpxml networks:
echo "- net-dumpxml networks..."
virsh net-list --name   # nur für Ausgabe
virsh net-list --name | xargs -I % sh -c "virsh net-dumpxml % > ${exportPath}/netdump_%.xml"
#if [ -f "${exportPath}/netdump_default.xml" ]; then
#	rm "${exportPath}/netdump_default.xml"
#fi


# dumpxml virtual machines:
echo "- dumpxml virtual machines..."
virsh list --all --name   # nur für Ausgabe
virsh list --all --name | xargs -I % sh -c "virsh dumpxml % > ${exportPath}/dump_%.xml"


# snapshot-dumpxml + snapshot-current
echo "- snapshot-dumpxml + snapshot-current..."
echo "  |"
domainList=$(virsh list --all --name)

for domain in ${domainList}; do
	echo "  -- domain: ${domain}"
	
	# snapshot-dumpxml
	snapshotList=$(virsh snapshot-list --name "${domain}")
	if [ -z "${snapshotList}" ]; then   # wenn leer
		echo -e "     |_snapshot:\e[0;33m keine Snapshots vorhanden\e[0;37m"
                                 #ab hier rote Schrift             ab hier weiße Schrift
	else
		for snapshot in ${snapshotList}; do
			echo "     |_snapshot: ${snapshot}"
			virsh snapshot-dumpxml "${domain}" "${snapshot}" > "${exportPath}/snapshotdump_${domain}_${snapshot}.xml"
		done

	#snapshot-current
		snapshotcurrent=$(virsh snapshot-current --name "${domain}")
		echo "     |_snapshotcurrent: ${snapshotcurrent}"
		echo "${snapshotcurrent}" > "${exportPath}/snapshotcurrent_${domain}.txt"

	fi
done

