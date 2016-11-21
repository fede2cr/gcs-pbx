#!/bin/bash

aptitude install sasl2-bin libsasl2 libsasl2-modules
sed -i 's/START=no/START=yes/' /etc/default/saslauthd

cat << EOF >> /etc/postfix/main.cf
smtpd_sasl_auth_enable = yes
smtpd_sasl2_auth_enable = yes
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes
smtpd_sasl_local_domain = $mydomain

smtpd_recipient_restrictions =
        permit_sasl_authenticated
        permit_mynetworks
        reject_unauth_destination

smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd


EOF

echo "mailhost.justbet.com    asterisk:@sterisk" >> /etc/postfix/sasl_passwd
chown root:root /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd
sed -i 's/relayhost = /relayhost = mailhost.justbet.com/' /etc/postfix/main.cf

postfix reload

