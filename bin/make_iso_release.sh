#!/bin/bash

# Script to generate ISO installer
# TODO:
# Create daily release or use version from argument
# Copy files directly from ISO

SRC=`pwd`/..
TMP=`mktemp -d`
SVN_ROOT=`pwd`/../..

cd $TMP
echo -n "Exporting from SVN... "
svn export $SVN_ROOT
mv cc-pbx/trunk/src/iso .
mv cc-pbx iso/
echo -n "Generating ISO file... "
genisoimage -q -J -l -b isolinux/isolinux.bin -no-emul-boot \
  -boot-load-size 4 -boot-info-table -z -iso-level 4 \
  -c isolinux/isolinux.cat -o ./autoinstall.iso iso/ &> /dev/null
echo "Done"
echo "Image file in $TMP/autoinstall.iso"

