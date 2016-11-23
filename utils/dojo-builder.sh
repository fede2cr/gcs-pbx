#!/bin/bash
# $1 = directory to perform the find /var/www/prog/cqcs
# $2 = $generated tbt.profile.js
# $3 = generated dojo.js
# ./builder.sh DIR gcs-profiles.js gcs-dojo.js
cat <<EOF > profiles/$2 
dependencies = {
	layers: [
	{
		name: "$3",
		dependencies: [
`find $1 -type f -exec cat {} \; -name '*.html' -or -name '*.php' -or -name '*.js'  -or -name '*.htm'| sed -e 's/\/\/.*$//'| sed -e ':a;N;$!ba;s/\/\*[.\n]*\*\///g' | sed -e 's/\s//g'| sed -e 's/[\;\}\{]/\n/g' | grep dojo.require| awk -F\" '{ print "\t\t\t\""$2"\","}'| egrep [^\.]dojo|sort -u`
		]
	},
	{
		name: "../dijit/dijit.js",
		dependencies: [
`find $1 -type f -exec cat {} \; -name '*.html' -or -name '*.php' -or -name '*.js'  -or -name '*.htm'| sed -e 's/\/\/.*$//'| sed -e ':a;N;$!ba;s/\/\*[.\n]*\*\///g' | sed -e 's/\s//g'| sed -e 's/[\;\}\{]/\n/g' | grep dojo.require| awk -F\" '{ print "\t\t\t\""$2"\","}'| egrep [^\.]dijit|sort -u`
		]
	},
	],
	prefixes: [
		 [ "dijit", "../dijit" ],
		[ "dojox", "../dojox" ],
	]
}
EOF
./build.sh profileFile=profiles/$2 action=release cssOptimize=comments optimize=shrinkSafe localeList="en-us,es-es" 
