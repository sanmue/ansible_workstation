#!/usr/bin/env bash

#set -x   # enable debug mode

REPO_NAME="ansible_workstation"
repo_path=$(find "${HOME}" -type d -name "${REPO_NAME}")

# Check if repo_path empty (path to folder 'REPO_NAME' not found)
if [ -z "${repo_path}" ]; then
    echo -e "\e[31m- Folder '${REPO_NAME}' not found."

    repo_path="${HOME}/.${REPO_NAME}_repo"
    echo "- setting target repo_path to '${repo_path}'"

    # Check if new path for REPR_DIR already exists (already cloned)
    if [ ! -d "${repo_path}" ]; then # if repo dir does not yet exist
        git clone https://gitlab.com/sanmue/ansible_workstation.git "${repo_path}"
    else # if repo already exists (cloned) -> update
        cd "${repo_path}" && git pull
    fi
else
    # will not be executed, since repo will be cloned in if-statement above, if folder REPO_NAME not found
    echo -e "- Folder '${REPO_NAME}' found at: \n${repo_path}"
fi

# Check number of parameters
if [ $# -le 0 ] || [ $# -gt 1 ]; then # if no parameter or more than 1 parameter passed
    echo -e "\e[31m- No parameter or more than 1 parameter passed to the script.\e[0m"
    exit 1
else
    tag="${1}"
    echo "- Parameter passed to the script: '${tag}'"
fi

# sudo in advance, only if systemwide conf/cmd required
sudo true && ansible-playbook "${repo_path}/local.yml" -v -K --tags "${tag}"
