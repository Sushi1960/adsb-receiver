#!/bin/bash

#####################################################################################
#                                   ADS-B FEEDER                                    #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015 Joseph A. Prochazka                                            #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

BUILDDIR=$PWD
BASHDIR=$BUILDDIR/../bash
HTMLDIR=$BUILDDIR/portal/html

# Assign the Lighthttpd document root directory to a variable.
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
DOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

source ../bash/functions.sh

clear

echo -e "\033[31m"
echo "-------------------------------------------"
echo " Now ready to install ADS-B Portal."
echo "-------------------------------------------"
echo -e "\033[33mThe goal of the ADS-B Portal project is to create a very"
echo "light weight easy to manage web interface for dump-1090 installations"
echo "This project is at the moment very young with only a few of the planned"
echo "featured currently available at this time."
echo ""
echo "https://github.com/jprochazka/dump1090-portal"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

clear

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
CheckPackage cron
CheckPackage collectd
CheckPackage rrdtool

## SETUP THE PORTAL WEBSITE

echo -e "\033[33m"
echo "Setting up performance graphs..."
echo -e "\033[37m"
chmod +x $BASHDIR/portal/graphs.sh
$BASHDIR/portal/graphs.sh

if [ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    echo -e "\033[33m"
    echo -e "Inserting the Planefinder ADS-B Client links...\033[37m"

    PLACEHOLDER="<!-- Plane Finder ADS-B Client Link Placeholder -->"
    IPADDRESS=`ip addr | grep 'state UP' -A2 | tail -n1 | awk -F'[/ ]+' '{print $3}'`
    HTMLLINK="<li id=\"planefinder-link\"><a href=\"http://${IPADDRESS}:30053\">Plane Finder Client</a></li>"
    sudo sed -i "s@${PLACEHOLDER}@${HTMLLINK}@g" ${HTMLDIR}/templates/default/master.tpl.php
fi

echo -e "\033[33m"
echo -e "Placing portal files in Lighttpd's root directory...\033[37m"
sudo cp -R ${HTMLDIR}/* ${DOCUMENTROOT}

echo -e "\033[33m"
echo -e "Setting permissions on data files...\033[37m"
sudo chmod +w ${DOCUMENTROOT}/data/*.xml

echo -e "\033[33m"
echo -e "Removing conflicting redirect from the Lighttpd dump1090.conf file...\033[37m"
# Remove this line completely.
sudo sed "/$(echo '  "^/dump1090$" => "/dump1090/gmap.html"' | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/d" /etc/lighttpd/conf-available/89-dump1090.conf
# Remove the trailing coma from this line.
sudo sed "s/$(echo '"^/dump1090/$" => "/dump1090/gmap.html",' | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/$(echo '"^/dump1090/$" => "/dump1090/gmap.html"' | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/g"  /etc/lighttpd/conf-available/89-dump1090.conf

echo -e "\033[33m"
echo -e "Configuring Lighttpd...\033[37m"
sudo tee -a /etc/lighttpd/conf-available/89-adsb-portal.conf > /dev/null <<EOF
# Block all access to the data directory accept for local requests.
$HTTP["remoteip"] !~ "127.0.0.1" {
    $HTTP["url"] =~ "^/data/" {
        url.access-deny = ( "" )
    }
}
EOF

echo -e "\033[33m"
echo "Restarting Lighttpd..."
echo -e "\033[37m"
sudo /etc/init.d/lighttpd restart

## SETUP COMPLETE

echo -e "\033[33m"
echo "Installation and configuration of the performance graphs is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE
