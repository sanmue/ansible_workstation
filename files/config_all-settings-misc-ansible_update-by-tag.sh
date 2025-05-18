#!/usr/bin/env bash

#set -x   # enable debug mode

REPO_DIR="${HOME}/Downloads/ansible_workstation_repo"

# Check number of parameters
if [ $# -le 0 ] || [ $# -gt 1 ]; then # if no parameter or more than 1 parameter passed
    echo -e "No parameter or more than 1 parameter passed.\nEnding script."
    exit 1
else
    tag="${1}"
fi


if [ ! -d "${REPO_DIR}" ]; then # if repo dir does not yet exist
    git clone https://gitlab.com/sanmue/ansible_workstation.git "${REPO_DIR}"
else # if repo already cloned -> update
    cd "${REPO_DIR}" && git pull
fi

# sudo in advance, only if systemwide conf/cmd required
sudo true && ansible-playbook "${REPO_DIR}/local.yml" -v -k --tags "${tag}"

