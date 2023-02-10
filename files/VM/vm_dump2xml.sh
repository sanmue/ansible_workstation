#!/bin/bash

exportPath=$(pwd)

# net-dumpxml networks:
echo "- net-dumpxml networks..."
sudo virsh net-list --name   # nur für Ausgabe
sudo virsh net-list --name | xargs -I % sh -c "sudo virsh net-dumpxml % > ${exportPath}/netdump_%.xml"
#if [ -f "${exportPath}/netdump_default.xml" ]; then
#	rm "${exportPath}/netdump_default.xml"
#fi


# dumpxml virtual machines:
echo "- dumpxml virtual machines..."
sudo virsh list --all --name   # nur für Ausgabe
sudo virsh list --all --name | xargs -I % sh -c "sudo virsh dumpxml % > ${exportPath}/dump_%.xml"


# snapshot-dumpxml + snapshot-current
echo "- snapshot-dumpxml + snapshot-current..."
echo "  |"
domainList=$(sudo virsh list --all --name)

for domain in ${domainList}; do
	echo "  -- domain: '${domain}'"
	
	# snapshot-dumpxml
	snapshotList=$(sudo virsh snapshot-list "${domain}" --name --topological)   #nur Name der Snapshots, in korrekter Reihenfolge
	if [ -z "${snapshotList}" ]; then   # wenn leer
		echo -e "     |_snapshot:\e[0;33m keine Snapshots vorhanden\e[0;37m"
                                 #ab hier rote Schrift             ab hier weiße Schrift
	else
		echo "     Exportiere sortierte Namensliste der Snapshots in Datei..."
		echo "${snapshotList}" > "snapshotList_${domain}.txt"

		echo "     Exportiere die einzelnen Snapshots in eine Datei..."
		for snapshot in ${snapshotList}; do
			echo "     |_snapshot-dumpxml: '${snapshot}'"
			sudo virsh snapshot-dumpxml "${domain}" "${snapshot}" | tee "${exportPath}/snapshotdump_${domain}_${snapshot}.xml" 1>/dev/null
		done

	#snapshot-current
		snapshotcurrent=$(sudo virsh snapshot-current --name "${domain}")
		echo "     |_snapshotcurrent: '${snapshotcurrent}'"
		echo "${snapshotcurrent}" > "${exportPath}/snapshotcurrent_${domain}.txt"

	fi
done

