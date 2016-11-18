<?
function cleanInput($input) {
	$search = array(
		'@<script[^>]*?>.*?</script>@si',   // Strip out javascript
		'@<[\/\!]*?[^<>]*?>@si',            // Strip out HTML tags
		'@<style[^>]*?>.*?</style>@siU',    // Strip style tags properly
		'@<![\s\S]*?--[ \t\n\r]*>@'         // Strip multi-line comments
	);
	$output = preg_replace($search, '', $input);
	return $output;
}
function phonePrint($phoneNumber) {
	if (preg_match("/priv/i",$phoneNumber)){#In case of a private number do not format
		return $phoneNumber;
	}
	if (strlen($phoneNumber) > 10){#International number format
		$pattern = '/(\d)(\d{3})(\d{3})(\d{4})/';
		preg_match($pattern, $phoneNumber, $matches);
		$phoneNumber = $matches[1]."-(".$matches[2].")-".$matches[3]."-".$matches[4];
	}
	return $phoneNumber;
}

function secstoHHMMSS($seconds){
	$hrs = floor($seconds / 3600);
	$mins = floor(($seconds / 60) % 60);
	$secs = $seconds % 60;
	return sprintf('%02d',$hrs).":".sprintf('%02d',$mins).":".sprintf('%02d',$secs);
}

function sanitize($input) {
	if (is_array($input)) {
		foreach($input as $var=>$val) {
			$output[$var] = sanitize($val);
		}
	}else{
		if (get_magic_quotes_gpc()) {
			$input = stripslashes($input);
		}
		$output  = cleanInput($input);
	}
	return $output;
}
function basicReport(){
	global $start_date,$end_date,$report_type,$keyword,$export_type;
	//require_once "Spreadsheet/Excel/Writer.php";
	$xls = NULL;
	$sheet = NULL;
	$format = NULL;
	$format_bold = NULL;
	$date_format = NULL;
	$HHMMSS = NULL;
	// number of seconds in a day
	$seconds_in_a_day = 86400;
	// Unix timestamp to Excel date difference in seconds
	$ut_to_ed_diff = $seconds_in_a_day * 25569;
	$idcounter = 0;
	$sql = "SELECT events.id,(CASE queue WHEN 0 THEN 'None' ELSE queue END) AS queue,agent,event_date,(CASE duration WHEN NULL then 'On Progress' ELSE duration END) AS duration,(CASE src WHEN '' THEN 'PRIVATE' ELSE src END) AS src,dst,wait_time FROM events,callinfo WHERE event_type = '$report_type' AND event_date > '$start_date' AND event_date < '$end_date' AND callinfo.eventid = events.id";
	if ($keyword != ""){
		if ($report_type == "inbound"){
			$sql .= " AND queue LIKE '%".$keyword."%'";
		}
		if ($report_type == "outbound"){
			$sql .= " AND dst LIKE '%".$keyword."%'";
		}
		if ($report_type == "abandon"){
			$sql .= " AND src LIKE '%".$keyword."%'";
		}
	}
	$result = mysql_query($sql);
	if ($export_type == "json"){
		print "{\"identifier\": \"id\",";
		#Starting JSON items scope;
		print "  \"items\"    : [";
	}else{
		$xls =& new Spreadsheet_Excel_Writer();
		$xls->send("basicreport.xls");
		$sheet =& $xls->addWorksheet('Report');
		$format_bold =& $xls->addFormat();
		$format_bold->setBold();
		$format_bold->setBorder(2);
		$format->setColor('black');
		$date_format =& $xls->addFormat();
		$date_format->setNumFormat('YYYY-MM-D h:mm:ss');
		$HHMMSS =& $xls->addFormat();
		$HHMMSS->setNumFormat('h:mm:ss');
		switch ($report_type){
			case "outbound":
				$sheet->write(0,0,"Caller",$format_bold);
				$sheet->write(0,1,"Destination",$format_bold);
				$sheet->write(0,2,"Date",$format_bold);
				$sheet->write(0,3,"Duration",$format_bold);
				break;
			case "inbound":
				$sheet->write(0,0,"Caller",$format_bold);
				$sheet->write(0,1,"Queue",$format_bold);
				$sheet->write(0,2,"Wait Time",$format_bold);
				$sheet->write(0,3,"Date",$format_bold);
				break;
			case "xfer":
				$sheet->write(0,0,"Caller",$format_bold);
				$sheet->write(0,1,"Agent",$format_bold);
				$sheet->write(0,2,"Queue",$format_bold);
				$sheet->write(0,3,"Destination",$format_bold);
				$sheet->write(0,4,"Wait Time",$format_bold);
				$sheet->write(0,5,"Date",$format_bold);
				$sheet->write(0,6,"Duration",$format_bold);
				break;
			case "abandon":
				$sheet->write(0,0,"Caller",$format_bold);
				$sheet->write(0,1,"Queue",$format_bold);
				$sheet->write(0,2,"Wait Time",$format_bold);
				$sheet->write(0,3,"Date",$format_bold);
				break;
		}

	}
	if (mysql_num_rows($result) == 0){#If there are no results
		if ($export_type == "json"){
			print "]}";
			exit;
		}else{
			$xls->close();
		}
	}
	while($row = mysql_fetch_assoc($result)){
		if ($export_type == "json"){
			if ($idcounter != 0){
				print ",";
			}
		}
		$row['dst'] = phonePrint($row['dst']);
		$row['src'] = phonePrint($row['src']);
		$idcounter++;
		if ($export_type == "json"){
			print "{";
			print "\"id\" : \"".$row['id']."\",";
			print "\"src\" : \"".$row['src']."\",";
			print "\"queue\" : \"".$row['queue']."\",";
			print "\"wait_time\" : \"".$row['wait_time']."\",";
			if ($report_type != "abandon"){
				print "\"agent\" : \"".$row['agent']."\",";
				print "\"duration\" : \"".$row['duration']."\",";
				print "\"dst\" : \"".$row['dst']."\",";
			}
			print "\"event_date\" : \"".$row['event_date']."\"";
			print "}";
		}else{
			$event_date = getdate(strtotime($row['event_date']));
			$excel_date = ($event_date[0] + $ut_to_ed_diff)/$seconds_in_a_day;
			$duration = getdate(strtotime($row['duration']));
			$excel_duration = ($duration[0] + $ut_to_ed_diff)/$seconds_in_a_day;
			$wait_time = getdate(strtotime($row['wait_time']));
			$excel_wait_time = ($wait_time[0] + $ut_to_ed_diff)/$seconds_in_a_day;
			switch ($report_type){
				case "outbound":
					$sheet->write(0,0,$row['agent'],$format);#Caller
					$sheet->write(0,1,$row['dst'],$format);#Destination
					$sheet->write(0,2,$excel_date,$date_format);#Date
					$sheet->write(0,3,$excel_duration,$format);#Duration
					break;
				case "inbound":
					$sheet->write(0,0,$row['src'],$format);#Caller
					$sheet->write(0,1,$row['queue'],$format);#Queue
					$sheet->write(0,2,$excel_wait_time,$format);#Wait Time
					$sheet->write(0,3,$excel_date,$format);#Date
					break;
				case "xfer":
					$sheet->write(0,0,$row['src'],$format);#Caller
					$sheet->write(0,1,$row['agent'],$format);#Agent
					$sheet->write(0,2,$row['queue'],$format);#Queue
					$sheet->write(0,3,$row['dst'],$format);#Destination
					$sheet->write(0,4,$excel_wait_time,$format);#Wait Time
					$sheet->write(0,5,$excel_date,$format);#Date
					$sheet->write(0,6,$excel_duration,$format);#Duration
					break;
				case "abandon":
					$sheet->write(0,0,$row['src'],$format);#Caller
					$sheet->write(0,1,$row['queue'],$format);#Queue
					$sheet->write(0,2,$excel_wait_time,$format);#Wait Time
					$sheet->write(0,3,$excel_date,$format);#Date
					break;
			}
		}
	}
	if ($export_type == "json"){
		print "]}";
	}
}
function resetArray($queueArray){
	$queueArray["inbound"] = 0;
	$queueArray["outbound"] = 0;
	$queueArray["abandon"] = 0;
	$queueArray["xfer"] = 0;
	$queueArray["internal"] = 0;
	return $queueArray;
}
function queueReport(){
	global $start_date,$end_date,$report_type,$keyword,$export_type;
	$idcounter = 0;
	$sql = "SELECT (CASE queue WHEN 0 THEN 'None' ELSE queue END) AS queue,(CASE event_type WHEN 'avaya' THEN 'internal' ELSE event_type END) AS event_type,count(*) AS events FROM events WHERE event_type != 'pause_start' AND event_type != 'pause_end' AND event_date > '$start_date' AND event_date < '$end_date'";
	if($keyword != ""){
		$sql.= " AND queue LIKE '%$keyword%' ";
	}
	$sql.= " GROUP BY queue,event_type";
	$result = mysql_query($sql);
	print "{\"identifier\": \"id\",";
	#Starting JSON items scope;
	print "  \"items\"    : [";
	if (mysql_num_rows($result) == 0){#If there are no results
		print "]}";
		exit;
	}
	$currentqueue = "-1";
	$currentqueuearray = Array();
	$currentqueuearray = resetArray($currentqueuearray);
	$totalcalls = 0;
	while($row = mysql_fetch_assoc($result)){
		if ($row['queue'] != $currentqueue){
			if ($currentqueue!= "-1"){#We have valid currentqueue to process.
				if ($idcounter != 0){
					print ",";
				}
				$idcounter++;
				print "{";
				print "\"id\" : \"".$idcounter."\",";
				print "\"queue\" : \"".$currentqueue."\",";
				foreach ($currentqueuearray as $key => $value){
					print "\"".$key."\": \"".$value."\",";
					print "\"".$key."percent\": \"".round(($value == 0?0:(($value * 100)/ $totalcalls)),4)."%\",";
				}	
				print "\"totalcalls\" : \"".$totalcalls."\"";
				print "}";
			}
			$currentqueuearray = resetArray($currentqueuearray);
			$currentqueue = $row['queue'];
			$totalcalls = 0;
		}
		$currentqueuearray[$row['event_type']] += $row['events'];
		$totalcalls += $row['events'];
	}
	if ($currentqueue!= "-1"){#We have valid currentqueue to process.
		if ($idcounter != 0){
			print ",";
		}
		$idcounter++;
		print "{";
		print "\"id\" : \"".$idcounter."\",";
		print "\"queue\" : \"".$currentqueue."\",";
		foreach ($currentqueuearray as $key => $value){
			print "\"".$key."\": \"".$value."\",";
			print "\"".$key."percent\": \"".round(($value == 0?0:(($value * 100)/ $totalcalls)),4)."%\",";
		}	
		print "\"totalcalls\" : \"".$totalcalls."\"";
		print "}";
	}
	print "]}";
}
function callDetail(){
	global $start_date,$end_date,$export_type;
	$idcounter = 0;
	$sql = "SELECT uniqueid,events.id,(CASE queue WHEN 0 THEN 'None' ELSE queue END) AS queue,agent,(CASE event_type WHEN 'avaya' THEN 'internal' ELSE event_type END) AS event_type, event_date,dst,src,dst,wait_time,(CASE duration WHEN NULL then 'On Progress' ELSE duration END) AS duration FROM events,callinfo WHERE event_date > '$start_date' AND event_date < '$end_date' AND callinfo.eventid = events.id ORDER BY uniqueid, event_date";
	$result = mysql_query($sql);
	print "{ \"identifier\": \"id\",";
	print "\"label\": \"src\",";
	print "\"items\": [";
	if (!$result || mysql_num_rows($result) == 0){#If there are no results
		print "]}";
		exit;
	}
	#Otherwise we have an open {[
	$currentuniqueid = "-1";
	$totalagents = 0;
	$totalduration = 0;
	$totalwaittime = 0;
	$curdate = 0;
	$curtype = 0;
	$curqueue = 0;
	while($row = mysql_fetch_assoc($result)){
		$row['dst'] = phonePrint($row['dst']);
		$row['src'] = phonePrint($row['src']);
		$idcounter++;
		$newuniqueid = $row['uniqueid'];
		if ($currentuniqueid != $newuniqueid){
			if ($currentuniqueid != "-1"){#Not the first time run this so we need to close the {[
				#We have a new uniqueid, time to print the totals for this uniqueid
				print "],";
				print "\"totIndate\": \"$curdate\",";
				print "\"totType\": \"$curtype\",";
				print "\"totQueue\": \"$curqueue\",";
				print "\"totAgents\": \"$totalagents Agent(s)\",";
				print "\"totEvents\": \"$totalagents\",";
				print "\"totDuration\": \"$totalduration\",";
				print "\"totDst\": \" \",";
				print "\"totWaittime\": \"$totalwaittime\"";
				print "},";
				#Reinitialize values;
				$totalagents = 0;
				$totalevents = 0;
				$totalduration = 0;
				$totalwaittime = 0;
				$totalduration = 0;
			}
			$currentuniqueid = $newuniqueid;
			#This is a new record
			print "{";
			print "\"id\": \"".$idcounter."\",";
			print "\"src\": \"".$row['src']."\",";
			print "\"uniqueid\": \"".$currentuniqueid."\",";
			print "\"events\": [";#We close the ]} on the above if.
			$curdate = $row['event_date'];
			$curtype = $row['event_type'];
			$curqueue = $row['queue'];
		}else{
			print ",";
		}
		$totalagents++;
		$totalduration+= $row['duration'];
		$totalwaittime+= $row['wait_time'];
		print "{";
		$idcounter++;
		print "\"id\": \"$idcounter\",";
		print "\"indate\": \"".$row['event_date']."\",";
		print "\"event_type\": \"".$row['event_type']."\",";
		print "\"queue\": \"".$row['queue']."\",";
		print "\"agent\": \"".$row['agent']."\",";
		print "\"waittime\": \"".$row['wait_time']."\",";
		print "\"dst\": \"".$row['dst']."\",";
		print "\"seconds\": \"".$row['duration']."\"";
		print "}";
	}
	#totIndate,totType,totQueue,totAgents,totWaittime,totDuration
	#Close latest open entry
	print "],";
	print "\"totIndate\": \" \",";
	$idcounter++;
	print "\"id\": \"$idcounter\",";
	print "\"totType\": \"$curtype\",";
	print "\"totIndate\": \"$curdate\",";
	print "\"totQueue\": \"$curqueue\",";
	print "\"totAgents\": \"$totalagents Agent(s)\",";
	print "\"totEvents\": \"$totalagents\",";
	print "\"totDuration\": \"$totalduration\",";
	print "\"totDst\": \" \",";
	print "\"totWaittime\": \"$totalwaittime\"";
	print "}";
	print "]}";
}
function agentDetail(){
	global $start_date,$end_date,$keyword,$export_type;
	$sql = "SELECT agent,(CASE queue WHEN 0 THEN 'None' ELSE queue END) AS queue,event_date,(CASE event_type WHEN 'avaya' THEN 'internal' ELSE event_type END) AS event_type,(CASE queue WHEN 0 THEN (CASE dst WHEN '' THEN 'PRIVATE NUMBER' ELSE dst END) ELSE (CASE src WHEN '' THEN 'PRIVATE NUMBER' ELSE src END) END) AS dst,wait_time,(CASE duration WHEN NULL then 'On Progress' ELSE duration END) AS duration FROM events,callinfo WHERE event_type != 'abandon' AND callinfo.eventid = events.id AND event_date > '$start_date' AND event_date < '$end_date' AND agent != '0' AND duration IS NOT NULL ";
	if ($keyword != ""){
		$sql.=" AND agent LIKE '%".$keyword."%'";
	}
	$sql .=" ORDER BY agent,event_date";
	$result = mysql_query($sql);
	print "{ \"identifier\": \"id\",";
	print "\"label\": \"agent\",";
	print "\"items\": [";
	if (mysql_num_rows($result) == 0){#If there are no results
		print "]}";
		exit;
	}
	$currentuniqueid = "-1";
	$totalagents = 0;
	$totalduration = 0;
	$totalwaittime = 0;
	$totalinbound = 0;
	$totaloutbound = 0;
	$totalxfer = 0;
	$totalinboundsecs = 0;
	$totaloutboundsecs = 0;
	$totalxfersecs = 0;
	while($row = mysql_fetch_assoc($result)){
		$row['dst'] = phonePrint($row['dst']);
		$row['src'] = phonePrint($row['src']);
		$idcounter++;
		$newuniqueid = $row['agent'];
		if ($currentuniqueid != $newuniqueid){
			if ($currentuniqueid != "-1"){#Not the first time run this so we need to close the {[
				#We have a new uniqueid, time to print the totals for this uniqueid
				#totQueue,totIndate,totType,totSrc,totWaittime,totDuration
				print "],";
				print "\"totQueue\": \"Open for details\",";
				print "\"totType\": \"Inbounds:$totalinbound.<br />Outbounds:$totaloutbound.<br />Internals:$totalxfer.\",";
				print "\"totIndate\": \"Open for details\",";
				print "\"totSrc\": \"$totalagents Call(s)\",";
				print "\"totDurationText\": \"Inbound:".secstoHHMMSS($totalinboundsecs).".<br />Outbound:".secstoHHMMSS($totaloutboundsecs).".<br />Internal: ".secstoHHMMSS($totalxfersecs).".<br />Total:".secstoHHMMSS($totalduration).".\",";
				print "\"totDuration\": \"$totalduration\",";
				print "\"totWaittime\": \"$totalwaittime\",";
				print "\"totDst\": \"$totalagents Call(s)\"";
				print "},";
				#Reinitialize values;
				$totalagents = 0;
				$totalevents = 0;
				$totalduration = 0;
				$totalwaittime = 0;
				$totalduration = 0;
				$totalinbound = 0;
				$totaloutbound = 0;
				$totalxfer = 0;
				$totalinboundsecs = 0;
				$totaloutboundsecs = 0;
				$totalxfersecs = 0;
			}
			$currentuniqueid = $newuniqueid;
			#This is a new record
			print "{";
			print "\"id\": \"".$idcounter."\",";
			print "\"agent\": \"".$row['agent']."\",";
			print "\"queue\": \"".$row['queue']."\",";
			print "\"calls\": [";#We close the ]} on the above if.
		}else{
			print ",";
		}
		$totalagents++;
		$totalduration+= $row['duration'];
		$totalwaittime+= $row['wait_time'];
		switch ($row['event_type']){
			case "inbound":
				$totalinbound++;
				$totalinboundsecs+=$row['duration'];
				break;
			case "outbound":
				$totaloutbound++;
				$totaloutboundsecs+=$row['duration'];
				break;
			case "internal":
			default:
				$totalxfer++;
				$totalxfersecs+=$row['duration'];
				break;
		}
		print "{";
		$idcounter++;
		print "\"id\": \"$idcounter\",";
		print "\"event_date\": \"".$row['event_date']."\",";
		print "\"event_type\": \"".$row['event_type']."\",";
		print "\"queue\": \"".$row['queue']."\",";
		print "\"agent\": \"".$row['agent']."\",";
		print "\"dst\": \"".$row['dst']."\",";
		print "\"wait_time\": \"".$row['wait_time']."\",";
		print "\"duration\": \"".$row['duration']."\"";
		print "}";
	}
	#totIndate,totType,totQueue,totSrc,totWaittime,totDuration
	#Close latest open entry
	print "],";
	print "\"totIndate\": \"Open for Details\",";
	$idcounter++;
	print "\"id\": \"$idcounter\",";
	print "\"totType\": \"Inbounds:$totalinbound.<br />Outbounds:$totaloutbound.<br />Internals:$totalxfer.\",";
	print "\"totQueue\": \"Open for Details\",";
	print "\"totSrc\": \"$totalagents Call(s)\",";
	print "\"totDurationText\": \"Inbound:".secstoHHMMSS($totalinboundsecs).".<br />Outbound:".secstoHHMMSS($totaloutboundsecs).".<br />Internal: ".secstoHHMMSS($totalxfersecs).".<br />Total:".secstoHHMMSS($totalduration).".\",";
	print "\"totDuration\": \"$totalduration\",";
	print "\"totWaittime\": \"$totalwaittime\",";
	print "\"totDst\": \"$totalagents Call(s)\"";
	print "}";
	print "]}";
}
require_once "config.php.inc";
mysql_connect('localhost',$mysql_username,$mysql_password);
mysql_select_db('pbxreports');
$start_date = sanitize(isset($_REQUEST['start_date'])?$_REQUEST['start_date']:date("Y-m-d"));
$start_date.=" 00:00:00";
$end_date = sanitize(isset($_REQUEST['end_date'])?$_REQUEST['end_date']:date("Y-m-d",date("U")+86400));
$end_date.=" 23:59:59";
$report_type = sanitize(isset($_REQUEST['report_type'])?$_REQUEST['report_type']:"calldetail");
$keyword = sanitize(isset($_REQUEST['keyword'])?$_REQUEST['keyword']:"");
$export_type = sanitize(isset($_REQUEST['export_type'])?$_REQUEST['export_type']:"json");
/*$agentfile = fopen("/etc/asterisk/agents.conf","r");
$agentcontent = fread($agentfile,filesize("/etc/asterisk/agents.conf"));
$agentlines = explode("\n",$agentcontent);
$agents = array();
foreach($agentlines as $line){
	if (preg_match('/^agent =>/',$line)){
		$sections = explode(",",$line);
		$agentid = explode(" ",$sections[0]);
		$agents[$agentid[2]] = $sections[2];
	}
}
fclose($agentfile);*/
switch($report_type){
	case "abandon":
	case "inbound":
	case "outbound":
	case "xfer":
		basicReport();
		break;
	case "queuestats":
		queueReport();
		break;
	case "agentdetail":
		agentDetail();
		break;
	case "calldetail":
	default:
		callDetail();
		break;
}
