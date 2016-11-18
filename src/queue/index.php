<?php
/* HTML 4.01 validated at 2008-01-03 */
require_once('functions.inc.php');

$socket=login($socket);

$comando = "Action: queuestatus\r\n";
$respuesta = exec_cmd($comando,$socket,"Event: QueueStatusComplete");
$colas=ArmaArrayColas($respuesta);
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd">
<html>
<head>
<script language="javascript" type="text/javascript">
<!--
function popitup(url) {
	newwindow=window.open(url,'name','height=300,width=250');
	if (window.focus) {newwindow.focus()}
	return false;
}

// -->
</script>

<title>Queue Monitor</title>
<meta http-equiv="refresh" content="25">
<link rel="stylesheet" href="mapi.css">
</head>
	<body>

	<?php

$queue_id=$_GET["queue_id"];

if (isset($queue_id)) {
	print_queue($colas, $socket, $queue_id);
} else {
	switch ($_SERVER['HTTP_HOST']) {
	case "cc-pbx":
	case "cc-pbx.greencore.co.cr":
	default:
		print_queues($colas, $socket);
		break;	
	}
}



$comando = "action: logoff\r\n";
exec_cmd($comando,$socket,"Message: Thanks for all the fish.");
fclose($socket);

	?>

	</body>
</html>
