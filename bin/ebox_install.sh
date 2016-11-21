#!/bin/bash
# Script para automatizar la instalaci?n de plataforma Ebox
# Copyright 2010, Greencore Solutions SRL
# info@greencore.co.cr
#

echo "deb http://ppa.launchpad.net/ebox/1.3/ubuntu karmic main" >> /etc/apt/sources.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 342D17AC
aptitude update
aptitude dist-upgrade
aptitude install ebox-network 

