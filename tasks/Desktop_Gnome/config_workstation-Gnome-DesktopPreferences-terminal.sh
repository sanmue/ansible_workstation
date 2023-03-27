#!/usr/bin/env bash

#set -x   # enable debug mode

# based on: https://askubuntu.com/questions/270469/how-can-i-create-a-new-profile-for-gnome-terminal-via-command-line
# (gsettings: https://ncona.com/2019/11/configuring-gnome-terminal-programmatically/)

dconfdir=/org/gnome/terminal/legacy/profiles:

create_new_profile() {
    local profile_ids=($(dconf list ${dconfdir}/ | grep -e '^:' |\
                        sed 's/\///g' | sed 's/://g'))
    local profile_name="$1"
    local profile_ids_old="$(dconf read "$dconfdir"/list | tr -d "]")"
    local profile_id="$(uuidgen)"

    [ -z "${profile_ids_old}" ] && local profile_ids_old="["  # if there's no `list` key
    [ ${#profile_ids[@]} -gt 0 ] && local delimiter=,  # if the list is empty
    dconf write ${dconfdir}/list \
        "${profile_ids_old}${delimiter} '${profile_id}']"
    dconf write "${dconfdir}/:${profile_id}"/visible-name "'${profile_name}'"
    echo "${profile_id}"
}


# ######################################
# ### Create profile - "Custom_Standard"
id=$(create_new_profile Custom_Standard)
# Preferences:
dconf write "${dconfdir}/:${id}"/background-color "'rgb(23,20,33)'"
dconf write "${dconfdir}/:${id}"/foreground-color "'rgb(208,207,204)'"
dconf write "${dconfdir}/:${id}"/palette "['rgb(23,20,33)', 'rgb(192,28,40)', 'rgb(38,162,105)', 'rgb(162,115,76)', 'rgb(18,72,139)', 'rgb(163,71,186)', 'rgb(42,161,179)', 'rgb(208,207,204)', 'rgb(94,92,100)', 'rgb(246,97,81)', 'rgb(51,209,122)', 'rgb(233,173,12)', 'rgb(42,123,222)', 'rgb(192,97,203)', 'rgb(51,199,222)', 'rgb(255,255,255)']"
dconf write "${dconfdir}/:${id}"/use-theme-colors "false"
dconf write "${dconfdir}/:${id}"/default-size-columns "100"
dconf write "${dconfdir}/:${id}"/default-size-rows "28"
# dconf write "${dconfdir}/:${id}"/font "'Monospace 14'"
dconf write "${dconfdir}/:${id}"/font "'MesloLGM Nerd Font 12'"
dconf write "${dconfdir}/:${id}"/use-system-font "false"
dconf write "${dconfdir}/:${id}"/cursor-shape "'underline'"

# Set as default profile:
#dconf write "${dconfdir}/default" "'$id'"


# ######################################
# ### Create profile - "Custom_SSH"
id=$(create_new_profile Custom_SSH)
# Preferences:
dconf write "${dconfdir}/:${id}"/background-color "'rgb(0,0,0)'"
dconf write "${dconfdir}/:${id}"/foreground-color "'rgb(0,255,0)'"
dconf write "${dconfdir}/:${id}"/use-theme-colors "false"
dconf write "${dconfdir}/:${id}"/default-size-columns "100"
dconf write "${dconfdir}/:${id}"/default-size-rows "28"
dconf write "${dconfdir}/:${id}"/font "'MesloLGM Nerd Font 12'"
dconf write "${dconfdir}/:${id}"/use-system-font "false"
dconf write "${dconfdir}/:${id}"/cursor-shape "'underline'"
#dconf write "${dconfdir}/:${id}"/visible-name "Custom_SSH"


# ######################################
# ### Create profile - "Custom_Root"
id=$(create_new_profile Custom_Root)
# Preferences:
dconf write "${dconfdir}/:${id}"/background-color "'rgb(9,9,9)'"
dconf write "${dconfdir}/:${id}"/foreground-color "'rgb(213,0,0)'"
dconf write "${dconfdir}/:${id}"/use-theme-colors "false"
dconf write "${dconfdir}/:${id}"/default-size-columns "100"
dconf write "${dconfdir}/:${id}"/default-size-rows "28"
dconf write "${dconfdir}/:${id}"/font "'MesloLGM Nerd Font 12'"
dconf write "${dconfdir}/:${id}"/use-system-font "false"
dconf write "${dconfdir}/:${id}"/cursor-shape "'underline'"

# ###############################################################################
# ###############################################################################

# ### $ gsettings list-schemas | grep org.gnome.Terminal
# org.gnome.Terminal.ProfilesList
# org.gnome.Terminal.Legacy.Settings
#
# ### $ gsettings get org.gnome.Terminal.ProfilesList list
# ['b1dcc9dd-5262-4d8d-a863-c897e6d979b9', 'dbf405e2-9686-4035-98c0-e23e25934e56']
# ### $ gsettings get org.gnome.Terminal.ProfilesList default
#'b1dcc9dd-5262-4d8d-a863-c897e6d979b9'
