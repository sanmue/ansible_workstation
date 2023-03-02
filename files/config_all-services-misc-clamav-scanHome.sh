#!/bin/bash

#set -x   # for debugging

###
### Skript scannt das HOME-Verzeichnis des ausführenden Users (default) nach Virus-Signaturen (ClamAV)
### oder einen übergebenen Pfad (1. Parameter) (sollte aktuell das HOME-Verzeichnis sein, da 
###                                            ExcludePath für qurantine-Verzeichnis entsprechend konfiguriert)
###

#######################
### Parameter/Variablen
#######################

scanPath="${HOME}"     # default-Wert
if [ $# -gt 0 ]; then
    scanPath="${1}"    # 1. Übergabe-Parameter an Script
fi

qurantineFolder="${scanPath}/.clam/quarantine"
logFolder="${scanPath}/.clam/logs/$(date +\%Y\%m\%d)-weekly.log"
PATH=/usr/bin

startMsgSubj="ClamAV (cronjob) - Scan started"
startMsg="${startMsgSubj} for path '${scanPath}'.\nScript: '$0'"
finMsgSubj="ClamAV (cronjob) - Scan finished"
finMsg="${finMsgSubj} for path '${scanPath}'.\nScript: '$0'"
errMsgSubj="ClamAV (cronjob) - Error"
errMsg="${errMsgSubj}, path '${scanPath}' does not exist.\nScript: '$0'"


##############
### Funktionen
##############
function notify_allGuiUser { 
	# Param1: Notify Subject
    # Param2: Notify Message

    for ADDRESS in /run/user/*; do
        USERID=${ADDRESS#/run/user/}
        /usr/bin/sudo -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" PATH=${PATH} \
        /usr/bin/notify-send -i dialog-warning "${1}" "${2}"
    done 
}

function mail_allLogonUser { 
	# Param1: Mail Subject
    # Param2: Mail Message
    arrUser=($(users))      # array of logged on users

    for user in ${arrUser}; do
        echo -e "${2}" | /usr/bin/mail -s "${1}" "${user}"
    done
}


########
### main
########

# ### --------------
# ### Check scanPath
# ### --------------
if [ ! -d "${scanPath}" ]; then
    # --- Send an alert to all graphical users:
    notify_allGuiUser "${errMsgSubj}" "${errMsg}"
    # --- Send (local) mail alert to all logged on users:
    mail_allLogonUser "${errMsgSubj}" "${errMsg}"

    exit 1
fi

# ### --------------------------------
# ### Send start notification to users
# ### --------------------------------

# --- Send an alert to all graphical users:
notify_allGuiUser "${startMsgSubj}" "${startMsg}"
# --- Send (local) mail alert to all logged on users:
mail_allLogonUser "${startMsgSubj}" "${startMsg}"

# ### -------
# ### Scanjob
# ### -------
# https://serverfault.com/questions/957666/how-to-make-clamdscan-exclude-folders-and-only-log-infected
/usr/bin/clamdscan --fdpass --multiscan --move="${qurantineFolder}" --log="${logFolder}" "${scanPath}" 2>/dev/null 1>&2

# ### --------------------------------
# ### Send final notification to users
# ### --------------------------------

# --- Send an alert to all graphical users:
notify_allGuiUser "${finMsgSubj}" "${finMsg}"
# --- Send (local) mail to all logged on users:
mail_allLogonUser "${finMsgSubj}" "${finMsg}"

