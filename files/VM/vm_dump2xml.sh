#!/bin/bash

exportPath=$(pwd)

# export VM Net's:
virsh net-list --name | xargs -I % sh -c "virsh net-dumpxml % > ${exportPath}/netdump_%.xml"
if [ -f "${exportPath}/netdump_default.xml" ]; then
	rm "${exportPath}/netdump_default.xml"
fi

# export VMs:
virsh list --all --name | xargs -I % sh -c "virsh dumpxml % > ${exportPath}/dump_%.xml"
