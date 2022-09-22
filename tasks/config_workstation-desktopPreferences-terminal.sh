#!/bin/bash

# based on: https://askubuntu.com/questions/270469/how-can-i-create-a-new-profile-for-gnome-terminal-via-command-line
# (gsettings: https://ncona.com/2019/11/configuring-gnome-terminal-programmatically/)

dconfdir=/org/gnome/terminal/legacy/profiles:

create_new_profile() {
    local profile_ids=($(dconf list $dconfdir/ | grep ^: |\
                        sed 's/\///g' | sed 's/://g'))
    local profile_name="$1"
    local profile_ids_old="$(dconf read "$dconfdir"/list | tr -d "]")"
    local profile_id="$(uuidgen)"

    [ -z "$profile_ids_old" ] && local profile_ids_old="["  # if there's no `list` key
    [ ${#profile_ids[@]} -gt 0 ] && local delimiter=,  # if the list is empty
    dconf write $dconfdir/list \
        "${profile_ids_old}${delimiter} '$profile_id']"
    dconf write "$dconfdir/:$profile_id"/visible-name "'$profile_name'"
    echo $profile_id
}


######################################
### Create profile - "Custom_Standard"
id=$(create_new_profile Custom_Standard)
# Preferences:
dconf write "$dconfdir/:$id"/background-color "'rgb(0,43,54)'"
dconf write "$dconfdir/:$id"/foreground-color "'rgb(131,148,150)'"
dconf write "$dconfdir/:$id"/use-theme-colors "true"
dconf write "$dconfdir/:$id"/default-size-columns "100"
dconf write "$dconfdir/:$id"/default-size-rows "28"
dconf write "$dconfdir/:$id"/font "'Monospace 14'"
dconf write "$dconfdir/:$id"/use-system-font "false"

# Set as default profile:
dconf write "$dconfdir/default" "'$id'"


######################################
### Create profile - "Custom_SSH"
id=$(create_new_profile Custom_SSH)
# Preferences:
dconf write "$dconfdir/:$id"/background-color "'rgb(0,0,0)'"
dconf write "$dconfdir/:$id"/foreground-color "'rgb(0,255,0)'"
dconf write "$dconfdir/:$id"/use-theme-colors "false"
dconf write "$dconfdir/:$id"/default-size-columns "100"
dconf write "$dconfdir/:$id"/default-size-rows "28"
dconf write "$dconfdir/:$id"/font "'Monospace 14'"
dconf write "$dconfdir/:$id"/use-system-font "false"


######################################
### Create profile - "Custom_Root"
id=$(create_new_profile Custom_Root)
# Preferences:
dconf write "$dconfdir/:$id"/background-color "'rgb(9,9,9)'"
dconf write "$dconfdir/:$id"/foreground-color "'rgb(213,0,0)'"
dconf write "$dconfdir/:$id"/use-theme-colors "false"
dconf write "$dconfdir/:$id"/default-size-columns "100"
dconf write "$dconfdir/:$id"/default-size-rows "28"
dconf write "$dconfdir/:$id"/font "'Monospace 14'"
dconf write "$dconfdir/:$id"/use-system-font "false"

################################################################################
################################################################################

### $ gsettings list-schemas | grep org.gnome.Terminal
# org.gnome.Terminal.ProfilesList
# org.gnome.Terminal.Legacy.Settings
#
### $ gsettings get org.gnome.Terminal.ProfilesList list
# ['b1dcc9dd-5262-4d8d-a863-c897e6d979b9', 'dbf405e2-9686-4035-98c0-e23e25934e56']
### $ gsettings get org.gnome.Terminal.ProfilesList default
#'b1dcc9dd-5262-4d8d-a863-c897e6d979b9'
