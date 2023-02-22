#!/bin/bash

PATH=/usr/bin
ALERT="Signature detected by clamav: '${CLAM_VIRUSEVENT_VIRUSNAME}' in '${CLAM_VIRUSEVENT_FILENAME}'"

# ### Send an alert to all graphical users:
for ADDRESS in /run/user/*; do
    USERID=${ADDRESS#/run/user/}
    /usr/bin/sudo -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" PATH=${PATH} \
    /usr/bin/notify-send -i dialog-warning "Virus found!" "$ALERT"
done


# ### Send (local) mail alert to all logged on users:
# - https://www.shellcheck.net/wiki/SC2207
# - https://www.golinuxcloud.com/bash-split-string-into-array-linux/
# - IFS (Internal Field Separator)

#arrUser=()
#IFS=" " read -r -A arrUser <<< "$(users)"  # funktioniert bei zsh (Archlinux)
#IFS=" " read -r -a arrUser <<< "$(users)"  # funktioniert bei bash (Ubuntu)
arrUser=($(users))                          # funktioniert bei zsh (Archlinux) und bash (Ubuntu)

for user in ${arrUser}; do
    echo "${ALERT}" | /usr/bin/mail -s "Signature detected in '${CLAM_VIRUSEVENT_FILENAME}'" "${user}"
done

