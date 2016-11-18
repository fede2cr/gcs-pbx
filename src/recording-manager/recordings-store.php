<?php

function find_recordings($uniqueid) {
	$dir = "/var/spool/asterisk/monitor/";
	$filesArray = (glob($dir."*".$uniqueid."*") );
	foreach ($filesArray as $filename_w_path) {
		$filename = substr($filename_w_path,28,-4);
		if (count($filesArray) > 1 ) {
			if (is_readable($filename_w_path)) {
				if (preg_match("/^q/", $filename)) {
					$sequence = substr($filename,15,-30);
					$recordings[$sequence] = $filename;
				} else {
					$sequence = substr($filename,9,-30);
					$recordings[$sequence] = $filename;
				}
			} 		
		}
	}
	ksort($recordings);
	return $recordings;
}

$uniqueid = "asterisk-11094-1267996421.154";
$recordings = find_recordings($uniqueid);
// JSON Container gets printed here
//if (is_array($recordings)) {
//	print_r ($recordings);
//}

?>

