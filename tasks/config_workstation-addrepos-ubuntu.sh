#!/bin/bash

# Fix deprecation warning bei apt-update: Key is stored in legacy trusted.gpg keyring (/etc/apt/trusted.gpg)
#   - z.B.: http://ppa.launchpad.net/mozillateam/ppa/ubuntu/dists/jammy/InRelease: Key is stored in legacy trusted.gpg keyring (/etc/apt/trusted.gpg), see the DEPRECATION section in apt-key(8) for details.
# Quelle: https://askubuntu.com/questions/1407632/key-is-stored-in-legacy-trusted-gpg-keyring-etc-apt-trusted-gpg

for KEY in $( \
    apt-key --keyring /etc/apt/trusted.gpg list \
    | grep -E "(([ ]{1,2}(([0-9A-F]{4}))){10})" \
    | tr -d " " \
    | grep -E "([0-9A-F]){8}\b" \
); do
    K=${KEY:(-8)}
    apt-key export "${K}" \
    | sudo gpg --dearmour -o "/etc/apt/trusted.gpg.d/imported-from-trusted-gpg-${K}.gpg"
done
# once every ppa has caught up, this needs to be cleaned up again:
#rm -f /etc/apt/trusted.gpg.d/imported-from-trusted-gpg-*.gpg



# Set PPA Priority for Mozillateam and block Firefox from Ubuntu’s own repository
# Quelle: https://fostips.com/ubuntu-21-10-two-firefox-remove-snap/#rb-Step-2-Install-back-the-classic-Firefox-Deb-package
dir="/etc/apt/preferences.d"
mozfile="99mozillateamppa"

touch "${dir}/${mozfile}"

cat > "${dir}/${mozfile}" << EOF
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 501

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1

EOF
