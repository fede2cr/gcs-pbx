<?php

function login($socket) {
	include_once "config.php.inc";
	$socket = fsockopen("127.0.0.1","5038");
	fwrite($socket, "action: login\r\n");
	fwrite($socket, "username: ".$manager_username."\r\n");
	fwrite($socket, "secret: ".$manager_password."\r\n");
	fwrite($socket, "Events: off\r\n");
	$actionid=rand(000000000,9999999999);
	fwrite($socket, "actionid: ".$actionid."\r\n\r\n");
	if ($socket) {
	   while (!feof($socket)) {
	       $bufer=fgets($socket);
		if(stristr($bufer,"Authentication accepted")) {
	       		break;
		} elseif(stristr($bufer,"Authentication failed")) {
			print ("Manager authentication error");
			fclose ($socket);
			exit();
		}
	   }
	}
	return $socket; 
}

function arma_paquete($data) {
	$items=split("\r\n",$data);
	foreach ($items as $item) {
		if (strlen($item) > 0 ) {
			$tmp=split(": ",$item);
			$clave=$tmp[0];
			$valor=$tmp[1];
			$evento[$clave]=$valor;
		}
	}
	return $evento;
}

function extension_prop($socket,$extension) {
// Funcion para encontrar que est? haciendo una extensi?n. ?til para alguien est? ocupado con una llamada saliente
// Realizar un recorrido del array para encontrar la extensi?n sobre la que vamos a trabajar y luego otro recorrido para
//  encontrar el CID del canal con la que est? hablando, esto nos dice cual es el n?mero marcado

	$extension_list = exec_cmd("Action: Status\r\n",$socket,"Event: StatusComplete");
	foreach ($extension_list['eventos'] as $extensions) {
		if (array_key_exists('Event',$extensions) and $extensions['Event']=="Status" and $extensions['CallerID']==$extension) {
			$other_side = $extensions['Link'];
			break;
		}
	}
	foreach ($extension_list['eventos'] as $extensions) {
		if (array_key_exists('Event',$extensions) and $extensions['Event']=="Status" and $extensions['Channel']==$other_side) {
			return($extensions['CallerID']);
			break;
		}
	}
	return('Idle');
}


function chanspy($agent,$sup_ext,$socket) {
	fputs ($socket, "Action: Originate\r\n");
	fputs ($socket, "Channel: SIP/".$sup_ext."\r\n");
	fputs ($socket, "Exten: 556\r\n");
	fputs ($socket, "Timeout: 30000\r\n");
	fputs ($socket, "Priority: 1\r\n");
	fputs ($socket, "Variable: agent=".$agent."\r\n");
	fputs ($socket, "Context: from-internal\r\n\r\n");
	while(fgets($socket)==FALSE);
}

function exten_pause($raw_extension,$in_pause,$socket) {
	fputs ($socket, "Action: QueuePause\r\n");
	fputs ($socket, "Interface: Local/".$raw_extension."@from-queue\r\n");
	fputs ($socket, "Paused: ".$in_pause."\r\n\r\n");
	while(fgets($socket)==FALSE);
}

function extensionstate($extension,$socket) {

	fputs ($socket, "action: extensionstate\r\n");
	fputs ($socket, "exten: ".$extension."\r\n");
	fputs ($socket, "context: default\r\n\r\n");

/* Parece que no es necesario que se usen ciclos
   para traer el mensaje entero. Por ahora me la voy a jugar
   con traer el mensaje asumiendo la cantidad de líneas
   y si luego hay problemas por recibir otro mensaje, le
   agrego el id 
*/


/* Parche que se come lineas vacias, hasta que la informacion esta lista
   y elimina el problema con el campo del status, la verdad no se como funciona php
   pero por lo general en C el fgets, se bloquea hasta que la salida esta lista,
   aqui parece que no hace eso el fgets debuelve muchos errores tonz nos comemos los
   errores hasta que podamos leer la info que ocupamos y seguimos normalmente
   William.
*/
	fgets($socket, 4096);
        fgets($socket, 4096);
        fgets($socket, 4096);
        fgets($socket, 4096);
        $resultado['hint'] = fgets($socket, 4096);
        $resultado['status'] = fgets($socket, 4096);

	switch ($resultado['status']) {
		case "Status: 0\r\n":
		    $resultado['status']='Available';
		    break;
		case "Status: -1\r\n":
		    $resultado['status']='Phone Unplugged';
		    break;
		case "Status: 1\r\n":
		    $resultado['status']='Busy';
		    break;
		case "Status: 8\r\n":
		    $resultado['status']='Ringing';
		    break;
		default:
		    $resultado['status']="Acquiring information...";
	}	

	while(fgets($socket)==FALSE);
	return $resultado;

}

function exec_cmd($comando,$socket,$evento_fin) {
	$actionid=rand(000000000,9999999999);
	$actionid="actionid: ".$actionid."\r\n";
	$comando .= $actionid."\r\n";
	$paquete_mio=false;
	$data="";
	fwrite($socket, $comando);

	while (!feof($socket)) {
		$bufer=fgets($socket);
		$data .= $bufer;
		if(strtolower($bufer)==strtolower($actionid)) {
       			$paquete_mio=true;
       		}
       		if(strtolower($bufer)=="\r\n" && $paquete_mio==true) {
       			$paquete_mio=false;
       			$respuesta['eventos'][]=arma_paquete($data);
       			if(stristr($data,$evento_fin)) {
       				$data="";
       				return $respuesta;
       			} elseif(stristr($data,"Error")) {
       				return $respuesta;
       			}
       		}
	}
}


function ArmaArrayColas($qs_response) {
        foreach ($qs_response['eventos'] as $item) {
                if($item['Event'] == "QueueParams") {
                        $result[$item['Queue']]['Queue']=$item['Queue'];
                        $result[$item['Queue']]['Calls']=$item['Calls'];
                        $result[$item['Queue']]['Holdtime']=$item['Holdtime'];
                        $result[$item['Queue']]['Completed']=$item['Completed'];
                        $result[$item['Queue']]['Abandoned']=$item['Abandoned'];
                        $result[$item['Queue']]['ServiceLevel']=$item['ServiceLevel'];
                        $result[$item['Queue']]['ServicelevelPerf']=$item['ServicelevelPerf'];
                        $result[$item['Queue']]['Weight']=$item['Weight'];
                }
                elseif ($item['Event'] == "QueueMember") {
                        $i=count($result[$item['Queue']]['Miembros']);//indice del proximo miembro
                        $result[$item['Queue']]['Miembros'][$i]['Location']=$item['Location'];
                        $result[$item['Queue']]['Miembros'][$i]['Membership']=$item['Membership'];
                        $result[$item['Queue']]['Miembros'][$i]['Penalty']=$item['Penalty'];
                        $result[$item['Queue']]['Miembros'][$i]['CallsTaken']=$item['CallsTaken'];
                        $result[$item['Queue']]['Miembros'][$i]['LastCall']=$item['LastCall'];
                        $result[$item['Queue']]['Miembros'][$i]['Status']=$item['Status'];
                        $result[$item['Queue']]['Miembros'][$i]['Paused']=$item['Paused'];

                }
        }
        return $result;
}

function print_queues($colas, $socket) {

        foreach($colas as $cola) {
                print_queue($colas,$socket,$cola['Queue']);
        }

}


function print_queue($colas, $socket, $queue_id) { 

$agent_print_status=array(
                'AGENT_LOGGEDOFF' => 'Logged Off', 
                'AGENT_IDLE' => 'Available', 
                'AGENT_ONCALL' => 'On Call'
);


$colaHead_1='   <table width="100%" >
                <caption>Queue name: ';
$colaHead_2='
        </caption>
                <thead>
                  <tr>
                    <th width="38%">People waiting for an agent</th>
                    <th width="38%">Hold Time</th>
                    <th width="44%">Completed</th>
                    <th width="44%">Abandoned</th>
                  </tr>
                </thead>
                <tbody>';
$colaBotom='</tbody>
                                </table>';
$miembroHead='          <table width="100%" >
                <thead>
                  <tr>
                    <th colspan="11" style="background: #9DF589 url(images/bg_header.jpg) no-repeat;">Members</th>
                  </tr>
                  <tr>
                    <th width="40%">Agent</th>
                    <th width="16%">Calls from Queue</th>
                    <th width="13%">Last</th>
                    <th width="31%">Agent Status</th>
                  </tr>
                </thead>
                <tbody>';
$no_member_header= '<p>No agents logged</p>';
$miembroBotom=' </tbody>
                                        </table>';


                        echo($colaHead_1);
			echo('<a href="?queue_id='.$colas[$queue_id]['Queue'].'">');
			switch ($colas[$queue_id]['Queue']) {
				case "2001": echo ('CS Queue (2001)'); break;
				case "2002": echo ('VIP Queue (2002)'); break;
				case "2003": echo ('Y5600 Queue (2003)'); break;
				case "2004": echo ('Affiliates Queue (2004)'); break;
				case "2005": echo ('Sales Queue (2005)'); break;
			}
			echo ('</a>');
                        echo($colaHead_2);
                        echo('<tr>');
                        echo('<td>'.$colas[$queue_id]['Calls'].'</td>');
                        echo('<td>'.$colas[$queue_id]['Holdtime'].'</td>');
                        echo('<td>'.$colas[$queue_id]['Completed'].'</td>');
                        echo('<td>'.$colas[$queue_id]['Abandoned'].'</td>');
                        echo('</tr>');
			echo('</tbody>');
                        echo('</table>');
                        if (is_array($colas[$queue_id]['Miembros'])) {
                                echo($miembroHead);
				sort ($colas[$queue_id]['Miembros']);
                                foreach ($colas[$queue_id]['Miembros'] as $miembro) {
						$extension_number="";
						$raw_extension=substr($miembro['Location'],6,-11);
					        $agent_extension=extensionstate($raw_extension,$socket);
						$agent_status=$agent_extension['status'];
						switch ($agent_status) {
							case 'Available': 
								$extension_number=ampuser_name($raw_extension,$socket)." (".$raw_extension.")";
								if ( $miembro['Paused'] == 1 ) { 
									$agent_status = "Paused"; 
									$agent_status=$agent_status." <a href=\"actions.php\" onclick=\"return popitup('actions.php?action=unpause&amp;agent=".$raw_extension."')\">(Unpause)</a>";
								} else { 
									$onthephone = extension_prop($socket,$raw_extension);
									if ( $onthephone != "Idle" ) {
										$agent_status="Talking to: ".$onthephone." (outside the queue)";
										$clase='class="oncall"';
									} else {
										$clase='class="idle"';
										$agent_status=$agent_status." <a href=\"actions.php\" onclick=\"return popitup('actions.php?action=pause&amp;agent=".$raw_extension."')\">(Pause)</a>";
										$agent_status=$agent_status." <a href=\"actions.php\" onclick=\"return popitup('actions.php?action=agentloggoff&amp;agent=".$raw_extension."')\">(Log Off)</a>";
									}
								}
								break;
							case 'Logged Off': 
								$extension_number=$raw_extension;
								$clase='class="loggedoff"';
								$agent_status=$agent_status." <a href=\"agents.php\" onclick=\"return popitup('actions.php?action=agentlogin&amp;agent=".$raw_extension."')\">(Login wizzard)</a>";
								break;
							case 'On Call':
							case 'Busy':
								$extension_number=ampuser_name($raw_extension,$socket)." (".$raw_extension.")";
								$clase='class="oncall"';
								$agent_status=$agent_status." talking to: ".talking_to($raw_extension,$socket)." <a href=\"actions.php=\" onclick=\"return popitup('actions.php?action=chanspy&amp;agent=".$raw_extension."')\">Listen</a>";
								break;
						}

                                        $agent_extension=extensionstate($raw_extension,$socket);
                                        echo('<tr '.$clase.'>');
					echo ("<td>".$extension_number."</td>");
                                        echo('<td>'.$miembro['CallsTaken'].'</td>');
                                        if ( $miembro['LastCall'] != 0) {
                                                echo('<td>'.date('h:i:s A',$miembro['LastCall']).'</td>');
                                        } else {
                                                echo('<td>Hasn\'t taken calls</td>');
                                        }
                                        echo('<td>'.$agent_status.'</td>');
                                        echo('</tr>');
				$miembro="";
                                }
				echo($miembroBotom);
                          } else  {
                                echo($no_member_header);
                          }
}

function logoff_exten($raw_extension,$socket) {
        // TODO
        // Necesitamos saber en cuales colas esta. Por ahora lo haremos en las 5.
        fputs ($socket, "Action: QueueRemove\r\n");
        fputs ($socket, "Queue: 2001\r\n");
        fputs ($socket, "Interface: Local/".$raw_extension."@from-queue\r\n\r\n");
        while(fgets($socket)==FALSE);
        fputs ($socket, "Action: QueueRemove\r\n");
        fputs ($socket, "Queue: 2002\r\n");
        fputs ($socket, "Interface: Local/".$raw_extension."@from-queue\r\n\r\n");
        while(fgets($socket)==FALSE);
        fputs ($socket, "Action: QueueRemove\r\n");
        fputs ($socket, "Queue: 2003\r\n");
        fputs ($socket, "Interface: Local/".$raw_extension."@from-queue\r\n\r\n");
        while(fgets($socket)==FALSE);
        fputs ($socket, "Action: QueueRemove\r\n");
        fputs ($socket, "Queue: 2004\r\n");
        fputs ($socket, "Interface: Local/".$raw_extension."@from-queue\r\n\r\n");
        while(fgets($socket)==FALSE);
        fputs ($socket, "Action: QueueRemove\r\n");
        fputs ($socket, "Queue: 2005\r\n");
        fputs ($socket, "Interface: Local/".$raw_extension."@from-queue\r\n\r\n");
        while(fgets($socket)==FALSE);
}

function agent_callback_login($agent,$agent_extension,$socket) {
// This needs an extension like
// exten => _26XXXXXXXX,1,AgentCallbackLogin(${EXTEN:2:4}||${EXTEN:-4}@from-internal)
	fputs ($socket, "Action: Originate\r\n");
	fputs ($socket, "Channel: SIP/".$agent_extension."\r\n");
	fputs ($socket, "Exten: 26".$agent.$agent_extension."\r\n");
	fputs ($socket, "Timeout: 30000\r\n");
	fputs ($socket, "Priority: 1\r\n");
	fputs ($socket, "Context: from-internal\r\n\r\n");
	while(fgets($socket)==FALSE);
}


function logon_agent($extension,$queue,$socket) {
	fputs ($socket, "Action: QueueAdd\r\n");
	fputs ($socket, "Queue: ".$queue."\r\n");
	fputs ($socket, "Interface: ".$extension."\r\n\r\n");
	return $resultado;
}

function ampuser_name($raw_extension,$socket) {
	fputs ($socket, "Action: DBGet\r\n");
	fputs ($socket, "Family: AMPUSER/".$raw_extension."\r\n");
	fputs ($socket, "Key: cidname\r\n\r\n");
	fgets ($socket, 4096);
	fgets ($socket, 4096);
	fgets ($socket, 4096);
	fgets ($socket, 4096);
	fgets ($socket, 4096);
	fgets ($socket, 4096);
	$resultado = substr (fgets ($socket, 4096),5);
	while(fgets($socket)==FALSE);
	return $resultado;
}

function talking_to($raw_extension,$socket){
	// TODO
	// Maybe search for BridgeChannel where it matches $raw_extension, instead of doing to cycles
	$calls = exec_cmd("Action: CoreShowChannels\r\n",$socket,"Event: CoreShowChannel");
	foreach ($calls[eventos] as $tmp) {
		if (array_key_exists('Channel',$tmp) and preg_match("/{$raw_extension}/i",$tmp['Channel']) ) {
			$talking_to_channel = $tmp['BridgedChannel'];
			break;
		}

	}
	foreach ($calls[eventos] as $tmp) {
		if (array_key_exists('Channel',$tmp) and $tmp['Channel'] == $talking_to_channel ) {
			return $tmp['CallerIDnum'];
		}
		
	}
}

?>
