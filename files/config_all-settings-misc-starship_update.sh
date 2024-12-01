#!/usr/bin/env bash

# set -x   # enable debug mode

### ############################
### Update starship shell prompt
### (via systemd timer+service)
### ############################

### -------------------
### Parameter/Variablen
### -------------------
path="/root" # default value # download target for starship install script
logFilePath="/var/log"
logFileName="starship_update_systemd.log"
logfile="${logFilePath}/${logFileName}"
date=$(date)

touch "${logfile}"

if [ $# -gt 0 ]; then # if more than 0 parameter
    if [ "$(ls "${1}")" ]; then
        path="${1%/}" # 1. Übergabe-Parameter an Script muss Pfad sein; letztes Zeichen wird entfernt wenn '/'
    else
        echo "${date} - Path (Parameter 1) '${1}' not found, not updated." >> "${logfile}"
        exit 1
    fi
fi

### ----
### main
### ----

# --- Update:
echo "${date} - Starship update started (systemd) - path '${path}'" >> "${logfile}"
curl -sS https://starship.rs/install.sh > "$path/starship_install.sh" && chmod 755 "$path/starship_install.sh" && "$path/starship_install.sh" --yes # && rm "$path/starship_install.sh"
echo "${date} - Starship update finished (systemd) - path '${path}'" >> "${logfile}"
