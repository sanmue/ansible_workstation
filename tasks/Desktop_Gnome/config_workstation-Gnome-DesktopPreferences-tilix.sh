#!/usr/bin/env bash

#set -x   # enable debug mode

# based on: https://askubuntu.com/questions/270469/how-can-i-create-a-new-profile-for-gnome-terminal-via-command-line
# (gsettings: https://ncona.com/2019/11/configuring-gnome-terminal-programmatically/)

dconfdir=/com/gexperts/Tilix/profiles

create_new_profile() {
    local profile_name="$1"   # local profile_name="Test"
    local profile_id="$(uuidgen)"

    local arr_profileId=($(dconf list ${dconfdir}/ | sed 's/\///g'))
    [ ${#arr_profileId[@]} -gt 0 ] && local delimiter=', '
    if [ -z "${arr_profileId}" ]; then
        local profileList="['${profile_id}']"
    else
        local profileList="["
        for profileId in "${arr_profileId[@]}"; do
            profileList+="'${profileId}'${delimiter}"
        done
        profileList+="'${profile_id}']"
    fi

    dconf write ${dconfdir}/list "${profileList}"
    dconf write "${dconfdir}/${profile_id}"/visible-name "'${profile_name}'"
    
    echo "${profile_id}"
}


# ######################################
# ### Create profile - "Custom_Standard"
id=$(create_new_profile Custom_Standard)
# Preferences:
dconf write "${dconfdir}/${id}"/background-color "'#272822'"
dconf write "${dconfdir}/${id}"/foreground-color "'#F8F8F2'"
dconf write "${dconfdir}/${id}"/palette "['#000000', '#CC0000', '#4D9A05', '#C3A000', '#3464A3', '#754F7B', '#05979A', '#D3D6CF', '#545652', '#EF2828', '#89E234', '#FBE84F', '#729ECF', '#AC7EA8', '#34E2E2', '#EDEDEB']"
dconf write "${dconfdir}/${id}"/default-size-columns "100"
dconf write "${dconfdir}/${id}"/default-size-rows "32"
dconf write "${dconfdir}/${id}"/default-size-rows "32"
dconf write "${dconfdir}/${id}"/exit-action "'hold'"
dconf write "${dconfdir}/${id}"/font "'MesloLGM Nerd Font 12'"
dconf write "${dconfdir}/${id}"/use-system-font "false"
dconf write "${dconfdir}/${id}"/cursor-shape "'ibeam'"
dconf write "${dconfdir}/${id}"/terminal-bell "'sound'"
dconf write "${dconfdir}/${id}"/use-theme-colors "true"
#dconf write "${dconfdir}/:${id}"/visible-name "Custom_Standard" # s.o.: Parameter Funktion 'create_new_profile'

# Set as default profile:
dconf write "${dconfdir}/default" "'$id'"
