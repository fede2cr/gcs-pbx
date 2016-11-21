#!/bin/bash

#sed -i 's/deb http:\/\/us.archive.ubuntu.com/deb http:\/\/ubuntu-mirror/g' /etc/apt/sources.list
#sed -i 's/deb http:\/\/cr.archive.ubuntu.com/deb http:\/\/ubuntu-mirror/g' /etc/apt/sources.list
aptitude update
aptitude dist-upgrade -y

