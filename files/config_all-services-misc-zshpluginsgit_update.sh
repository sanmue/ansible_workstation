#!/usr/bin/env bash

#set -x   # enable debug mode

# ### ################################################################################################
# ### Skript macht ein Update der zsh plugins
# ### - diese wurden direkt vom git-repo bezogen
# ### - nur für Ubuntu; bei Archlinux, Manjaro über paket installiert
# ### ################################################################################################


#######################
### Parameter/Variablen
#######################
PATH=/usr/bin

zshpluginpath="/usr/share/zsh/plugins"

# https://stackoverflow.com/questions/9293887/reading-a-space-delimited-string-into-an-array-in-bash
# - https://stackoverflow.com/a/53369525
# https://stackoverflow.com/questions/24628076/convert-multiline-string-to-array

strZshPlugin="zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search"   # String
declare -a arrZshPlugin
eval "arrZshPlugin=(${strZshPlugin})"     # array # eval: if you need parameter expansion


githubPathZshusers="https://github.com/zsh-users"
logPath="/var/log"
logName="zshpluginsgit_update.service.log"

startMsgSubj="zsh plugin update (git) started"
startMsg="${startMsgSubj}.\nScript: '$0'"
finMsgSubj="zsh plugin update (git) finished"
finMsg="${finMsgSubj}.\nScript: '$0'"
errMsgSubj="zsh plugin update (git) - Error"
errMsg="${errMsgSubj}.\nScript: '$0'"


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
    arrUser=($(users))   # array of logged on users

    for user in ${arrUser}; do  # for user in "${arrUser[@]}"; do   # so müsste korrekt sein: TODO:test
        echo -e "${2}" | /usr/bin/mail -s "${1}" "${user}"
    done
}


########
### main
########

# ### ---------------------
# ### Check zsh pluginpaths
# ### ---------------------

for plugin in "${arrZshPlugin[@]}"; do
    if [ ! -d "${zshpluginpath}/${plugin}" ]; then
        # --- Send an alert to all graphical users:
        notify_allGuiUser "${errMsgSubj}" "${errMsg}"
        # --- Send (local) mail alert to all logged on users:
        mail_allLogonUser "${errMsgSubj}" "${errMsg} - Check plugin path for ${plugin}"

        echo "$(date), $0; Check zsh pluginpath, Error: '${zshpluginpath}/${plugin}' existiert nicht" >> "${logPath}/${logName}"

        # --- Send an alert to all graphical users:
        notify_allGuiUser "Clone ${plugin}" "Clone ${plugin}"
        # --- Send (local) mail alert to all logged on users:
        mail_allLogonUser "Clone ${plugin}" "Clone ${plugin}"

        echo "$(date), $0; Clone ${plugin}" >> "${logPath}/${logName}"
        /usr/bin/git clone "${githubPathZshusers}/${plugin}.git" "${zshpluginpath}/${plugin}" 1>/dev/null 2>> "${logPath}/${logName}"
    fi    
done

# ### --------------------------------
# ### Send start notification to users
# ### --------------------------------

# --- Send an alert to all graphical users:
notify_allGuiUser "${startMsgSubj}" "${startMsg}"
# --- Send (local) mail alert to all logged on users:
mail_allLogonUser "${startMsgSubj}" "${startMsg}"

# ### ---------------------------
# ### Update zsh plugins git repo
# ### ---------------------------

for plugin in "${arrZshPlugin[@]}"; do
    if [ -d "${zshpluginpath}/${plugin}" ]; then
        # --- Send an alert to all graphical users:
        notify_allGuiUser "zsh plugin update (git) - ${plugin}" "Updating repo for ${plugin}..."
        # --- Send (local) mail alert to all logged on users:
        mail_allLogonUser "zsh plugin update (git) - ${plugin}" "Updating repo for ${plugin}..."

        cd "${zshpluginpath}/${plugin}" && /usr/bin/git pull origin 1>/dev/null 2>> "${logPath}/${logName}"
    fi    
done

# ### --------------------------------
# ### Send final notification to users
# ### --------------------------------

# --- Send an alert to all graphical users:
notify_allGuiUser "${finMsgSubj}" "${finMsg}"
# --- Send (local) mail to all logged on users:
mail_allLogonUser "${finMsgSubj}" "${finMsg}"
