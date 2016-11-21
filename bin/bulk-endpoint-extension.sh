#!/bin/bash
# Script para creación automática de extensiones y configuración de
# Polycom 330
# Diseñado para Ubuntu 8.04.3 LTS y FreePBX 2.5.1
# Copyright 2009, Greencore Solutions SRL
# info@greencore.co.cr
#
PASSWORD=`pwgen -N 1`
export SRC=../src/

gawk -F: '{print "add,"$1","$3","$1",,,0,enabled,0,"$6",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,fixed,,"$1","$3",disabled,ogg,,,,,disabled,,,,attach=0,saycid=no,envelope=no,delete=no,,,,,,checked,checked,,,,,,,,,,,,,,,,,"}' extensiones-mac.txt > bulk-add-extensions.csv

gawk  -v SRC="../src/" -F: '{ print "cp "SRC"/tftpboot/MAC.cfg tftpboot/"$2".cfg"
	    print "cp "SRC"/tftpboot/MACreg.cfg tftpboot/"$2"reg.cfg"
	    print "sed -i s/MACADDRESSreg/"$2"reg/g tftpboot/"$2".cfg"
	    print "sed -i s/DISPLAYNAME/\""$3"\"/g tftpboot/"$2"reg.cfg"
	    print "sed -i s/ADDRESS/"$1"/g tftpboot/"$2"reg.cfg"
	    print "sed -i s/PASSWORD/"$6"/g tftpboot/"$2"reg.cfg"
          }' extensiones-mac.txt 
# | bash
