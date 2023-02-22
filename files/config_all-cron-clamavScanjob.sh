#!/bin/bash

#############
### Variablen
#############
PATH=/usr/bin
arrUser=($(users))   # array of logged on users

scanPath="/home/sandro"     # default-Wert
if [ $# -gt 0 ]; then
    scanPath="${1}"         # Übergabe-Parameter an Script
fi

if [ ! -d "${scanPath}" ]; then
    errMsgSubj="ClamAV (cronjob) - Fehler"
    errMsg="${errMsgSubj}: Path '${scanPath}' nicht vorhanden. \nScript: '$0'"

    for ADDRESS in /run/user/*; do
        USERID=${ADDRESS#/run/user/}
        /usr/bin/sudo -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" PATH=${PATH} \
        /usr/bin/notify-send -i dialog-warning "ClamAV" "${errMsg}"
    done    

    for user in ${arrUser}; do
        echo -e "${errMsg}" | /usr/bin/mail -s "${errMsgSubj}" "${user}"
    done

    exit 1
fi

startMsgSubj="ClamAV (cronjob) - Scan started"
startMsg="${startMsgSubj} for path '${scanPath}'. \nScript: '$0'"
finMsgSubj="ClamAV (cronjob) - Scan finished"
finMsg="${finMsgSubj} for path '${scanPath}'. \nScript: '$0'"


##############
### Funktionen
##############
# TODO


########
### main
########

# ### --------------------------------
# ### Send start notification to users
# ### --------------------------------

# --- Send an alert to all graphical users:
for ADDRESS in /run/user/*; do
    USERID=${ADDRESS#/run/user/}
    /usr/bin/sudo -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" PATH=${PATH} \
    /usr/bin/notify-send -i dialog-warning "ClamAV" "${startMsg}"
done

# --- Send (local) mail alert to all logged on users:
for user in ${arrUser}; do
    echo -e "${startMsg}" | /usr/bin/mail -s "${startMsgSubj}" "${user}"
done


# ### -------
# ### Scanjob
# ### -------

# /usr/bin/clamdscan --fdpass --multiscan --move="${scanPath}/.clam/quarantine" --log="${scanPath}/.clam/logs/$(date +\%Y\%m\%d)-weekly.log" "${scanPath}" 2>/dev/null 1>&2


# ### --------------------------------
# ### Send final notification to users
# ### --------------------------------

# --- Send an alert to all graphical users:
for ADDRESS in /run/user/*; do
    USERID=${ADDRESS#/run/user/}
    /usr/bin/sudo -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" PATH=${PATH} \
    /usr/bin/notify-send -i dialog-warning "ClamAV" "${finMsg}"
done

# --- Send (local) mail alert to all logged on users:
for user in ${arrUser}; do
    echo -e "${finMsg}" | /usr/bin/mail -s "${finMsgSubj}" "${user}"
done
