#!/bin/bash

# Copyright 2010, Greencore Solutions SRL
# Script para actualizar en masa y autom?ticamente el firmware
# de tel?fonos
# Actualmente trabaja con:
# Grandstream BT-200
# TODO:
# -Validad que el tel?fono se encuentra presente y que la contrase?a funciona
# -Funcion para detecci?n de tel?fono

SRC=`pwd`/..
PATCHES=$SRC/src/patches
TMP=`mktemp -d`
source $SRC/lib/versions.sh
menu=true

function install_fw {
# Case if $model
	( FW_DIR=/var/www/firmware/GS-BT200
	if [ ! -d $FW_DIR ]
	then	
		cd $TMP
		unzip -q $SRC/src/firmware/grandstream/Release_BT200_GXP_$FW_GS_BT200.zip
		mkdir -p $FW_DIR
		mv *bin $FW_DIR
		chown -Rv asterisk:asterisk $FW_DIR 
	fi )
}

function upgrade_fw {
# Case if $model
	gsutil -d $IP > $TMP/old-cfg-$IP.txt 2> /dev/null
	cp $TMP/old-cfg-$IP.txt $TMP/new-cfg-$IP.txt
	sed -i "s/^http_upgrade_url = .*$/http_upgrade_url = http:\/\/10.42.20.50\/firmware\/GS-BT200/" $TMP/new-cfg-$IP.txt
	sed -i "s/always_check_for_new_firmware = 0/always_check_for_new_firmware = 1/" $TMP/new-cfg-$IP.txt
	sed -i "s/automatic_http_upgrade = 0/automatic_http_upgrade = 1/" $TMP/new-cfg-$IP.txt
	sed -i "s/send_dtmf_mode = 8/send_dtmf_mode = 2/" $TMP/new-cfg-$IP.txt
	( gsutil -r $IP < $TMP/new-cfg-$IP.txt 2> /dev/null && gsutil -b $IP ) &
	{ for ((i = 0 ; i <= 100 ; i+=1)); do
	        sleep 1.2s
	        echo $i
	    done
	} | whiptail --gauge "Please wait" 5 50 0

	detect_fw_version
	if [ $FW_GS_BT200 != $fw_version ]
	then
		whiptail --title "Upgrade problem" --msgbox "There was a problem with the upgrade. Current version: $fw_version" 8 78
	else
		whiptail --title "Upgrade complete" --msgbox "Upgrade sucesfull to version $fw_version" 8 78
		GS_MAC=`gsutil -e $IP | gawk '{print $11}'`
		echo "$GS_MAC,$fw_version,$IP" >> /tmp/phone_upgrade.log
	fi
}

function fix_cfg {
# Case if $model
	gsutil -d $IP > $TMP/old-cfg-$IP.txt 2> /dev/null
	cp $TMP/old-cfg-$IP.txt $TMP/new-cfg-$IP.txt
	sed -i "s/send_dtmf_mode = 8/send_dtmf_mode = 2/" $TMP/new-cfg-$IP.txt
	sed -i "s/allow_auto_answer_by_call_info = 0/allow_auto_answer_by_call_info = 1/" $TMP/new-cfg-$IP.txt
	sed -i "s/turn_off_speaker_on_remote_disconnect = 0/turn_off_speaker_on_remote_disconnect = 1/" $TMP/new-cfg-$IP.txt
	sed -i "s/onhook_threshold = 8/onhook_threshold = 0/" $TMP/new-cfg-$IP.txt
# There is a bug in either the grandstream firmware or in gsutil, but can't modify remote_disconnect
	( gsutil -r $IP < $TMP/new-cfg-$IP.txt 2> /dev/null && gsutil -b $IP ) &
	{ # Waits for two minutes
	    for ((i = 0 ; i <= 100 ; i+=1)); do
	        sleep 0.25s
	        echo $i
	    done
	} | whiptail --title "Updating config" --gauge "Please wait" 5 50 0
	whiptail --title "Config complete" --msgbox "Configuration update complete" 8 78
	
}

function detect_fw_version {
# Case if $model
	fw_version=`gsutil -e $IP 2> /dev/null | gawk '{print $7}'`
}

while $menu
do
	action=$(whiptail --title "What action to perform" --menu "Select action to perform" 20 60 10 \
		"Upgrade" "Upgrades firmware of the phone" \
		"Config fix" "Modifies default options on the phones" 3>&1 1>&2 2>&3)
	model=$(whiptail --title "Model selection" --menu "Select model out of list" 20 60 10 \
		"GS-BT200" "Granstream BT-200 version $FW_GS_BT200" \
		"GS-GXV3140" "Granstream Videophone GXV3140 to version $FW_GS_GXV3140" 3>&1 1>&2 2>&3)
	IP=$(whiptail --inputbox "Enter the IP of the phone: " 10 30 3>&1 1>&2 2>&3)
	case $action in
		"Upgrade")
			detect_fw_version
			if [ $FW_GS_BT200 != $fw_version ]
			then
				whiptail --title "Upgrade process" --msgbox "Detected firmware "$fw_version", upgrading..." 8 78
				install_fw
				upgrade_fw
			else
				whiptail --title "Already updated" --msgbox "This phone is already running the latest version ($fw_version)" 8 78
			fi ;;
		"Config fix")
			fix_cfg
	esac
	whiptail --title "Continue?" --yesno "Do you wish to modify more phones?" 8 78 || menu=false
done
