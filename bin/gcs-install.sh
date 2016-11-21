#!/bin/bash
# Script para creación de central telefónica, para centro de contacto
# Diseñado para Ubuntu 9.10 y FreePBX 2.7
# Copyright 2009, 2010 Greencore Solutions SRL
# info@greencore.co.cr
#

# Todo: Config de cron-apt
# Cambiar FOPPASSWORD
# Default asterisk admin password
# Agregar adminlogo? (a freepbx)

SRC=`pwd`/..
PATCHES=$SRC/src/patches
PKG=`mktemp -d`
source $SRC/lib/versions.sh

# Custom configuration
TFTPSERVER=1
AMIPARSER=1
PBXREPORTS=1

# Instalación de paquetes y configuraciones estandar de GCS

dpkg --set-selections < $SRC/lib/dpkg-selections-cc-pbx
export DEBIAN_FRONTEND=noninteractive
apt-get -q -y dselect-upgrade || exit 0
mysqladmin -u root password "greencore"
/etc/init.d/mysql restart

AST_CDR_PASS=`pwgen -s -N 1`
AST_DB_PASS=`pwgen -s -N 1`
DBPASS="greencore"

echo -e "dash dash/sh boolean false" | debconf-set-selections
dpkg-reconfigure dash

usermod -s /bin/bash asterisk

sed -i s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"ipv6.disable=1\"/ /etc/defaults/grub
patch /etc/php5/apache2/php.ini < $PATCHES/apache2-php-ini.diff

patch /etc/apache2/envvars < $PATCHES/apache-envvars.diff
/etc/init.d/apache2 restart

# Fail2ban installer
cat $SRC/patches/jail.conf >> /etc/fail2ban/jail.conf
cat $SRC/patches/fail2ban-asterisk.conf >> /etc/fail2ban/filter.d/asterisk.conf


mkdir /usr/share/asterisk/agi-bin
chown -R asterisk:asterisk /usr/share/asterisk

cd $PKG
tar xzvf $SRC/src/freepbx-$FREEPBX_VER.tar.gz
( cd freepbx-$FREEPBX_VER
  mysqladmin create asteriskcdrdb -u root --password=$DBPASS
  mysqladmin create asterisk -u root --password=$DBPASS
  mysql -u root --password="$DBPASS" asteriskcdrdb < SQL/cdr_mysql_table.sql
  mysql -u root --password="$DBPASS" asterisk < SQL/newinstall.sql
  cat << EOF | mysql -u root --password="$DBPASS" mysql
GRANT ALL PRIVILEGES ON asteriskcdrdb.* TO asteriskuser@localhost IDENTIFIED BY '$AST_CDR_PASS';
GRANT ALL PRIVILEGES ON asterisk.* TO asteriskuser@localhost IDENTIFIED BY '$AST_DB_PASS';
FLUSH PRIVILEGES;
EOF

  cat << EOF >> amportal.conf
CDRDBPASS=$AST_CDR_PASS
AMPDBPASS=$AST_DB_PASS
EOF

  sed -i 's/AUTHTYPE=none/AUTHTYPE=database/g' amportal.conf
  sed -i 's/FOPRUN=true/FOPRUN=false/g' amportal.conf

#exit

  ./install_amp --dbhost=localhost --dbname=asterisk --username=root --password=$DBPASS --webroot=/var/www << EOF











EOF
  chown -R asterisk:asterisk /usr/share/asterisk/agi-bin
  /var/lib/asterisk/bin/module_admin reload
)

/var/lib/asterisk/bin/module_admin upgradeall
/var/lib/asterisk/bin/module_admin reload
for module in announcement fw_ari fw_fop daynight callforward callwaiting conferences disa miscapps miscdests backup weakpasswords ivr queues findmefollow timeconditions iaxsettings sipsettings 
do
 /var/lib/asterisk/bin/module_admin download $module
 /var/lib/asterisk/bin/module_admin install $module
done

( cd /var/www/admin/modules
  tar xfvz $SRC/src/agentadministration-1.0.tgz
  chown -Rv asterisk:asterisk agentadministration
  /var/lib/asterisk/bin/module_admin install agentadministration
)

( cd /var/www/admin/modules
  tar xzvf $SRC/src/customcontexts-0.3.3.tgz
  chown -Rv asterisk:asterisk customcontexts 
  /var/lib/asterisk/bin/module_admin install customcontexts
)

/var/lib/asterisk/bin/module_admin reload

sed -i "s/BACKGROUND=0/BACKGROUND=1/" /usr/sbin/safe_asterisk
update-rc.d -f asterisk remove
cp $PATCHES/modules.conf /etc/asterisk/modules.conf
cp $PATCHES/rc.local /etc/rc.local.orig
amportal restart &

# Add other extensions for pause/unpause and logoff
# Restric queue-manager's permission
( MANAGER_PASS=`pwgen -s -N 1`
  MANAGER_USER=queue-manager
  cd /var/www/
  cp -R $SRC/src/queue /var/www
  chown -R asterisk:asterisk queue
  cd queue
  sed -i s/USER/$MANAGER_USER/ functions.inc.php
  sed -i s/PASSWORD/$MANAGER_PASS/ functions.inc.php
  # This application needs a couple of extensions to be added
  cat $SRC/src/extensions_custom.conf >> /etc/asterisk/extensions_custom.conf
  cat << EOF >> /etc/asterisk/manager_custom.conf
[$MANAGER_USER]
secret = $MANAGER_PASS
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
read = system,call,log,verbose,command,agent,user
write = system,call,log,verbose,command,agent,user
EOF
  sed -i 's/\[default\]//g' /etc/asterisk/queues.conf
  cat << EOF >> /etc/cron.daily/queue-monitor
#!/bin/bash
#To daily, clear the queue stats
/usr/sbin/asterisk -rx "reload"
EOF
  chmod +x /etc/cron.daily/queue-monitor
)
sed -i s/PRIORITY=0/PRIORITY=10/ /usr/sbin/safe_asterisk
sed -i s/full\ \=\>\ notice,warning,error,debug,verbose/full\ \=\>\ notice,warning,error,verbose/ /etc/asterisk/logger.conf
chown -R asterisk:asterisk /usr/share/asterisk/agi-bin
cp -a /var/www/admin/modules/core/sounds/*sln /var/lib/asterisk/sounds/custom/* /usr/share/asterisk/sounds/en/
ln -s /var/lib/asterisk/moh /var/lib/asterisk/mohmp3 

# Adding demo configs
if [ -d $SRC/src/demo-config/Demo ]; then
	cp -r $SRC/src/demo-config/Demo /var/lib/asterisk/backups/
fi

if [ $ENDPOINT_CONFIGURATOR ]
then 
	sed -i 's/USE_INETD=true/USE_INETD=false/' /etc/default/atftpd
	/etc/init.d/atftpd restart
fi

if [ $AMIPARSER ]
then 
	mkdir -p /opt/ami-parser
	cp $SRC/src/ami-parser/amiparser.pl /opt/ami-parser
	mysql -u root -pgreencore < $SRC/src/ami-parser/pbxreports.sql
fi

if [ $PBXREPORTS ]
then 
	cp -r $SRC/src/pbxreports /var/www
	pear install channel://pear.php.net/ole-1.0.0RC1
	pear install Spreadsheet_Excel_Writer-0.9.2
fi

if [ $TFTPSERVER ]
then
	echo -n "Installing tftp files..."
	cp -r $SRC/src/tftpboot/* /var/lib/tftpboot
	chown -R nobody:nogroup /var/lib/tftpboot
	echo " Done."
fi

# Installing Index
cd /var/www
rm index.html
cp -R $SRC/src/index/* .
tar xfvz $SRC/src/dojo-custom-build.tar.gz
mv dojo-custom-build/release/dojo .
rm -rv dojo-custom-build
chown -R asterisk:asterisk .


# Últimos cambios realizados con Douglas
chmod u+x /var/lib/asterisk/backups
mkdir /var/lib/asterisk/backups/PBX-Reports-DB
mv $SRC/src/ccpbx-backup /etc/cron.daily/
chmod +x /etc/cron.daily/ccpbx-backup

# Limpieza
rm -r $PKG

# Pasos manuales
echo "Debe crear /var/www/queue/config.php.inc para reflejar la contraseña en /etc/asterisk/manager_custom.conf"

