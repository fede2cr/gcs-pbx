<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd">
<html>
<head>
	<link rel="stylesheet" href="mapi.css">
	<title>Agent control</title>
</head>
<body>
<table>

<?php 

/* HTML validated at 2008-01-06 */

require_once('functions.inc.php');

$socket=0;

global $socket;
$socket=login($socket);

if (array_key_exists("action", $_REQUEST)) {
	switch ($_REQUEST[action]) {
		case "agentloggoff": {
		echo ("Agent ".$_REQUEST["agent"]." is being logged off");
			logoff_exten($_REQUEST["agent"],$socket);
			break;
		// Solo es necesario mostrar que el agente fue deslogeado
		}
		case "pause": {
			echo ("Agent ".$_REQUEST[agent]." paused");
			exten_pause($_REQUEST[agent],1,$socket);
			break;
		}
		case "unpause": {
			echo ("Agent ".$_REQUEST[agent]." unpaused");
			exten_pause($_REQUEST[agent],0,$socket);
			break;
		}
		case "agentlogin": {
                        echo ("<FORM METHOD=GET ACTION=\"actions.php?action=chanspy\">");
                        echo ("Extension the agent is going to use: <INPUT NAME=\"agent-extension\"><BR>");
                        echo ("<input type=\"hidden\" name=\"agent\" value=\"".$_REQUEST[agent]."\">");
                        echo ("<INPUT TYPE=SUBMIT>");
                        echo ("</FORM>");
                        break;

		// Preg # de extension donde se va a sentar el agente, y realizar un originarte entre el CallBack y la extension en que estaría el agente
		}
		case "chanspy": {
			echo ("<FORM METHOD=GET ACTION=\"actions.php?action=chanspy\">");
			echo ("Your extension number: <INPUT NAME=\"sup-ext\"><BR>");
			echo ("<input type=\"hidden\" name=\"agent\" value=\"".$_REQUEST[agent]."\">");
			echo ("<INPUT TYPE=SUBMIT>");
			echo ("</FORM>");
			break;
		}
	}
}

if (array_key_exists("sup-ext",$_REQUEST)) {
	echo ("Sending ChanSpy to: ".$_REQUEST["sup-ext"]);
	chanspy($_REQUEST[agent],$_REQUEST["sup-ext"],$socket);
}

if (array_key_exists("agent-extension",$_REQUEST)) {
	echo ("Sending Log In request to extension ".$_REQUEST["agent-extension"]);
	agent_callback_login($_REQUEST[agent],$_REQUEST["agent-extension"],$socket);
}


fclose($socket);
echo ("<p><a href=\"javascript:self.close()\">Close</a></p>");


?>
</table>

</body>
</html>

