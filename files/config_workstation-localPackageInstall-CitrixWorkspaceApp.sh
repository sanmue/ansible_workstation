#!/usr/bin/env bash

#set -x   # enable debug mode

### install certificates for citrix workspace app (ica-client)
### by using mozilla certificates (mozilla firefox must be installed)
# Sources:
#	- https://wiki.ubuntuusers.de/Citrix_Workspace_App/
#	- https://stackoverflow.com/questions/66974260/citrix-workspace-ssl-error-61-while-connecting-from-ubuntu-20-04


# Initialization
mozillaCertPath='/usr/share/ca-certificates/mozilla'
citrixCertPath='/opt/Citrix/ICAClient/keystore/cacerts'
citrixUtilPath='/opt/Citrix/ICAClient/util'
citrixRehashApp='ctx_rehash'


# Check availability of mozilla firefox certificate folder
if [ ! -d ${mozillaCertPath} ]; then
	echo "Mozilla Certificate folder not available at '${mozillaCertPath}'."
	echo "Scipt will be exited."
	exit 2
fi

# copy mozilla firefox certificates to Citrix ICAClient cacerts folder
if [ ! -d "${citrixCertPath}" ]; then
	sudo mkdir -p "${citrixCertPath}"
fi
sudo rsync -aPhxv "${mozillaCertPath}/" "${citrixCertPath}/"

# convert all certificates in $citrixCertPath into PEM format
for file in "${citrixCertPath}"/*; do
	if [[ ${file} == *".crt"* ]]; then
		cutfile=$(cut -d . -f 1 <<< "${file}")   # Dateiname ohne Endung
		#echo "pem-filename: ${cutfile}.pem"
		#sudo openssl x509 -in "${citrixCertPath}/${file}" -out "${citrixCertPath}/${cutfile}.pem"
		sudo openssl x509 -in "${file}" -out "${cutfile}.pem"
	fi
done

# install libidn11 (required for ica-client, not part of standard-install of Ubuntu 22.04)
# sudo apt install -f -y libidn11-dev
# - hier nicht mehr benötigt, da bereits über ansible task installiert wird

# install ica-client
# z.B.: sudo apt install -f -y ./icaclient_22.12.0.12_amd64.deb

# install usb support package
# z.B.: sudo apt install -f -y ./ctxusb_22.12.0.12_amd64.deb

# rehash certificates for ica-client
if [ -d "${citrixUtilPath}" ]; then
	echo -e "\nRehashing certificates..."
	sudo "${citrixUtilPath}/${citrixRehashApp}"
else
	echo "Rehash of certificates not possibel, CitrixUtilPath does not exist."
	echo "Install ICA-Client and try again."
fi
