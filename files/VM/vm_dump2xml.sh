#!/bin/bash

exportPath=$(pwd)

# net-dumpxml virtual machine networks:
virsh net-list --name | xargs -I % sh -c "virsh net-dumpxml % > ${exportPath}/netdump_%.xml"
if [ -f "${exportPath}/netdump_default.xml" ]; then
	rm "${exportPath}/netdump_default.xml"
fi

# dumpxml virtual machines:
virsh list --all --name | xargs -I % sh -c "virsh dumpxml % > ${exportPath}/dump_%.xml"
