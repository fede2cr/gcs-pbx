#!/usr/bin/perl -w
#
# POR QUEUE:
# + Llamadas abandonadas: agent_history.event_type
# + Tiempo Espera promedio: client dst channel = agent_history.queue - agent contesta 
# + Tiempo de Abandono promedio: SUM(event_type 'abandon')
# + Duration: avg(duration) WHERE agent_history.queue 
# + Llamadas Sin Transferir: WHERE event_type != "abandon" AND "transfer" AND "realizada" event_type = 
# + Porcentaje de llamadas sin transferir: Arriba
# POR AGENT:
# + Llamadas recibidas: cdr WHERE dst = agente -- extension = 3xxx -- agente = 4xxx
# + Llamadas realizadas: Arriba (src en lugar de dst)
# + Tiempo loggeado: show agents
# + Tiempo disponible: SUM(loggedtime) - SUM(duration)
# TODO logoff events from phones

use strict;
use IO::Socket;
use CGI qw(:standard);
use CGI::Carp qw/fatalsToBrowser/;
use DBI;
my $dbh;

my $EOL = "\015\012";
my $BLANK = $EOL x 2;

my $sock = new IO::Socket::INET ( PeerAddr => 'localhost', PeerPort => '5038', Proto => 'tcp', Reuse => 1); 
die "Could not create socket: $!\n" unless $sock;

#my $fifo_fh;
#open($fifo_fh, "+< /var/www/prog/events.fifo") or die "The FIFO file \"/var/www/prog/events.fifo\" is missing, and this program can't run without it."; #TODO move to socket

my %channels = ();
sub request_agents{ 
	print "Requesting Agents\n";
	my $sock = shift;
	print $sock "Action: Agents$BLANK";
	my %item = ();
	while (<$sock>){
		print $_;
#		if (/(\d): (.*)$/){
#			$item{$1} = $2;
#		}
		last if (/^Event: AgentsComplete/);
	}
	print "Agent finished\n";
}
sub request_status{
	print "Requesting Status\n";
	my $sock = shift;
	print $sock "Action: Status$BLANK";
	my %item = ();
	while (<$sock>){
		print $_;
#		if (/(\d): (.*)$/){
#			$item{$1} = $2;
#		}
		last if (/^Event: StatusComplete/);
	}
#	print "Status finished\n";
}

sub dbhconnect {
	$dbh = shift;
	my $database = "pbxreports";
	my $hostname = "localhost";
	my $port = "3306";
	my $username = "root";
	my $password = 'greencore'; 
	my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
	$dbh =DBI->connect($dsn, $username, $password) or die "Couldn't connect to DB (field)...$dbh->errstr\n";
	return $dbh;
}


#Event: Dial
#Privilege: call,all
#Source: Local/3442@from-internal-f984,2
#Destination: SIP/3442-08248170
#CallerID: 3441
#CallerIDName: AAlvaro
#SrcUniqueID: asterisk-30339-1267898190.141
#DestUniqueID: asterisk-30339-1267898190.143

sub newDial{
	my ($data,$dbh,%channels) = @_;
	my ($channel,$srcUniqueID,$dstUniqueID) = ("") x 3;
	if ($data =~ /SrcUniqueID:\ (.*)\r/){
		$srcUniqueID = $1;
	}
	if ($data =~ /DestUniqueID:\ (.*)\r/){
		$dstUniqueID = $1;
	}
	if (exists $channels{$srcUniqueID}{"DBID"}){
#		#print "Xfer: Creating\n";
		#Active call, this is a transfer
		my $dstagent = $channels{$dstUniqueID}{"Channel"};
		if ($dstagent =~ /SIP\/3(\d+)-.*/){#Extension is 3xxx, Agents are 4xxx
			$dstagent = "4".$1;
		}
		$dbh = opendb($dbh);
		my $sth = "";
		my $sql = "UPDATE callinfo SET duration = (SELECT time_to_sec(timediff(now(),event_date)) FROM events WHERE id = ".$channels{$srcUniqueID}{"DBID"}.") WHERE eventid = ".$channels{$srcUniqueID}{"DBID"};#Clean the latest event duration
		$sth = $dbh->do($sql) or die $sth->errstr;	
		$sql = "INSERT INTO events(queue,agent,event_type,uniqueid) VALUES('".$channels{$srcUniqueID}{"Queue"}."','".$dstagent."','xfer','$srcUniqueID')"; #Add a new event for the transfer
		$sth = $dbh->do($sql) or die $sth->errstr;	
		my $id = $dbh->last_insert_id(undef, undef, qw(events id)) or die "no insert id?";
		$sql = "INSERT INTO callinfo(eventid,wait_time,src,dst) VALUES($id,0,'".$channels{$srcUniqueID}{"CallerID"}."','".$dstagent."')";#Insert the new call to the callinfo table
		$sth = $dbh->do($sql) or die $sth->errstr;	
		$channels{$srcUniqueID}{"DBID"} = $id;#Set a new DB Identifier
#		print "\$channels{$srcUniqueID} {DBID} = $id\n";
#		print "Xfer: Created\n";
	}
	return %channels;
}
#Event: Newchannel
#Privilege: call,all
#Channel: SIP/3441-081c7360
#State: Down
#CallerIDNum: 3441
#CallerIDName: device
#Uniqueid: asterisk-30339-1267898190.139
sub newChannel{
	my ($data,%channels) = @_;
	my ($channel,$uniqueid) = ("") x 2;
	if ($data =~ /Channel:\ (.*)\r/){
		$channel = $1;
	}
	if ($data =~ /Uniqueid:\ (.*)\r/){
		$uniqueid = $1;
	}
	$channels{$uniqueid}{"Channel"} = $channel;
	return %channels;
}
sub newState{
	my ($data,%channels) = @_;
	my ($channel,$uniqueid) = ("") x 2;
	if ($data =~ /CallerID:\ (.*)\r/){
		$channel = $1;
	}
	if ($data =~ /Uniqueid:\ (.*)\r/){
		$uniqueid = $1;
	}
	$channels{$uniqueid}{"CallerID"} = $channel;
	return %channels;
}
sub doJoin{
	my ($data,$dbh,%channels) = @_;
	my ($queue,$uniqueid) = ("") x 2;
	if ($data =~ /Queue:\ (.*)\r/){
		$queue = $1;
	}
	if ($data =~ /Uniqueid:\ (.*)\r/){
		$uniqueid = $1;
	}
	$channels{$uniqueid}{"Queue"} = $queue;
	$dbh = opendb($dbh);
	my $sql = "INSERT INTO events(queue,uniqueid) VALUES('$queue','$uniqueid')";
	my $sth;
	$sth = $dbh->do($sql) or die $sth->errstr;	
	my $id = $dbh->last_insert_id(undef, undef, qw(events id)) or die "no insert id?";
	$channels{$uniqueid}{"DBID"} = $id;
	#print "Inserting $uniqueid {".$channels{$uniqueid}{"CallerID"}."} call on Queue: $queue\n";
	#$sth = $dbh->do($sql) or die $sth->errstr;	
	#$sql = "SELECT LAST_INSERT_ID()";	
	#$sth = $dbh->prepare($sql);
	#$sth->execute() or die $sth->errstr;
	#my $id = $sth->fetchrow;
	#$sth->finish;
	#$channels{$uniqueid}{"DBID"} = $id;
	return %channels;
}
sub doLink{
	my ($data,$dbh,%channels) = @_;
	my ($uniqueid1,$uniqueid2) = ("") x 2;
	if ($data =~ /Uniqueid1:\ (.*)\r/){
		$uniqueid1 = $1;
	}
	if ($data =~ /Uniqueid2:\ (.*)\r/){
		$uniqueid2 = $1;
	}
	if ($data =~ /Channel2:\ Agent\/(.*)\r/){
		my $agent = $1;
		if (exists $channels{$uniqueid1} && exists $channels{$uniqueid1}{"DBID"}){#Uniqueid1 has the first insert
			$dbh = opendb($dbh);
			my $sql = "UPDATE events SET agent = '$agent' WHERE id = ".$channels{$uniqueid1}{"DBID"};
			my $sth = "";
			$sth = $dbh->do($sql) or die $sth->errstr;	
			my ($src,$dst) = ($channels{$uniqueid2}{"CallerID"},"");
			if ($channels{$uniqueid2}{"CallerID"} =~ /3\/(\d{3})/){
				$src = "4".$1;
			}
			if ($channels{$uniqueid2}{"Channel"} =~ /Agent\/(\d{4})/){
				$dst = $1;
			}
			$sql = "INSERT INTO callinfo(eventid,wait_time,duration,src,dst) VALUES(".$channels{$uniqueid1}{"DBID"}.",(SELECT time_to_sec(timediff(now(),event_date)) FROM events WHERE id = ".$channels{$uniqueid1}{"DBID"}."),0,'$src','$dst');";
			$sth = $dbh->do($sql) or die $sth->errstr;	
		}
	}
	if (exists $channels{$uniqueid1}) {
		$channels{$uniqueid1}{"Link"} = $uniqueid2;
	}
	if (exists $channels{$uniqueid2}){
		$channels{$uniqueid2}{"Link"} = $uniqueid1;
	}
	return %channels;
}
sub doUnlink{
	my ($data,$dbh,%channels) = @_;
	my ($uniqueid1,$uniqueid2) = ("") x 2;
	if ($data =~ /Uniqueid1:\ (.*)\r/){
		$uniqueid1 = $1;
	}
	if ($data =~ /Uniqueid2:\ (.*)\r/){
		$uniqueid2 = $1;
	}
	if ($data =~ /Channel2:\ Agent\/(.*)\r/){
		my $agent = $1;
		if (exists $channels{$uniqueid1} && exists $channels{$uniqueid1}{"DBID"}){#Uniqueid1 has the first insert
			$dbh = opendb($dbh);
			my $sql = "UPDATE callinfo SET duration = (SELECT time_to_sec(timediff(now(),event_date)) FROM events WHERE id = ".$channels{$uniqueid1}{"DBID"}.") WHERE eventid = ".$channels{$uniqueid1}{"DBID"};
			my $sth = "";
			$sth = $dbh->do($sql) or die $sth->errstr;	
		}
	}
	if ($data =~ /Channel2:\ SIP\/3(\d+)-.*\r/){
		my $agent = "4".$1;
		print "Xfer: Closing duration\n";
		if (exists $channels{$uniqueid1} && exists $channels{$uniqueid1}{"DBID"}){#Uniqueid1 has the first insert
			$dbh = opendb($dbh);
			my $sql = "UPDATE callinfo SET duration = (SELECT time_to_sec(timediff(now(),event_date)) FROM events WHERE id = ".$channels{$uniqueid1}{"DBID"}.") WHERE eventid = ".$channels{$uniqueid1}{"DBID"};
			my $sth = "";
			$sth = $dbh->do($sql) or die $sth->errstr;	
		}
	}
	return %channels;
}
sub doPause{
	my ($data,$dbh,%channels) = @_;
	my ($queue,$membername,$pausebool) = ("") x 3;
	if ($data =~ /Queue:\ (.*)\r/){
		$queue = $1;
	}
	if ($data =~ /MemberName:\ Agent\/(.*)\r/){
		$membername = $1;
	}
	if ($data =~ /Paused:\ (.*)\r/){
		$pausebool = $1;
	}
	if ($pausebool eq "1"){
		$pausebool = "pause_start";
	}else{
		$pausebool = "pause_end";
	}
	$dbh = opendb($dbh);
	my $sql = "INSERT INTO events(queue,agent,event_type) VALUES('$queue','$membername','$pausebool')";
	my $sth;
	$sth = $dbh->do($sql) or die $sth->errstr;	
	return %channels;
}
sub doLogChange{
	my ($data,$dbh,%channels) = @_;
	my ($queue,$membername,$pausebool) = ("") x 3;
	#Logintime: 34087
	if ($data =~ /Queue:\ (.*)\r/){
		$queue = $1;
	}
	#Agent: 4400
	if ($data =~ /MemberName:\ Agent\/(.*)\r/){
		$membername = $1;
	}
	if ($data =~ /Paused:\ (.*)\r/){
		$pausebool = $1;
	}
	if ($data =~ /Event: Agentcallbacklogoff/){
		$pausebool = "logoff";
	}else{
		$pausebool = "login";
	}
	$dbh = opendb($dbh);
	my $sql = "INSERT INTO events(queue,agent,event_type) VALUES('$queue','$membername','$pausebool')";
	my $sth;
	$sth = $dbh->do($sql) or die $sth->errstr;	
	return %channels;
}
sub doAbandon{
	my ($data,$dbh,%channels) = @_;
	my ($uniqueid,$holdtime) = ("") x 2;
	if ($data =~ /Uniqueid:\ (.*)\r/){
		$uniqueid = $1;
	}
	if ($data =~ /HoldTime:\ (.*)\r/){
		$holdtime = $1;
	}
	$dbh = opendb($dbh);
	my $sql = "UPDATE events SET event_type = 'abandon' WHERE id = ".$channels{$uniqueid}{"DBID"}.";";
	my $sth;
	$sth = $dbh->do($sql) or die $sth->errstr;	
	$sql = "INSERT INTO callinfo(eventid,wait_time,duration,src) VALUES(".$channels{$uniqueid}{"DBID"}.",$holdtime,0,'".$channels{$uniqueid}{"CallerID"}."');";
	$sth = $dbh->do($sql) or die $sth->errstr;	
	print "Abandoned call \$channels{$uniqueid}\n";
	return %channels;
}
#Event: Rename
#Privilege: call,all
#Oldname: SIP/3440-08248170
#Newname: SIP/3440-08248170<MASQ>
#Uniqueid: asterisk-30339-1267909826.206
#NewUniqueid: asterisk-30339-1267909826.203
sub doRename{
	my ($data,%channels) = @_;
	my ($uniqueid,$newUniqueid) = ("") x 2;
	if ($data =~ /[^w]Uniqueid:\ (.*)\r/){
		$uniqueid = $1;
	}
	if ($data =~ /NewUniqueid:\ (.*)\r/){
		$newUniqueid = $1;
		if (exists $channels{$uniqueid}) {
			while ( my ($attribute, $value) = each(%{$channels{$uniqueid}})){
#				print "Copying $uniqueid {$attribute} with value: $value to $newUniqueid\n";
				$channels{$newUniqueid}{$attribute} = $channels{$uniqueid}{$attribute};
#				print "Deleting $uniqueid {$attribute}\n";
				delete $channels{$uniqueid}{$attribute};
			}
			delete $channels{$uniqueid};
		}
	}
	return %channels;
}

#Event: Hangup
#Privilege: call,all
#Channel: Local/3441@from-internal-1332,1
#Uniqueid: asterisk-8847-1267929879.14
#Cause: 0
#Cause-txt: Unknown
sub doHangup{#Cleanup unused channels
	my ($data,%channels) = @_;
	my ($uniqueid,$newUniqueid) = ("") x 2;
	if ($data =~ /Uniqueid:\ (.*)\r/){
		$uniqueid = $1;
		if (exists $channels{$uniqueid}) {
			while ( my ($attribute, $value) = each(%{$channels{$uniqueid}})){
#				print "Deleting $uniqueid { $attribute } with value : $value\n";
				delete $channels{$uniqueid}{$attribute};
			}
			print "Deleted \$channels{$uniqueid}\n";
			delete $channels{$uniqueid};
		}
	}
	return %channels;
}
sub opendb {
	my $dbh = shift;
	if ( ! $dbh ) {
		$dbh = dbhconnect($dbh);
	}elsif ( ! $dbh->ping ) {
		$dbh = dbhconnect($dbh);
	}
	return $dbh;
}
sub closedb {
	my $dbh = shift;
	if ( $dbh && $dbh->ping ){ 
		$dbh->disconnect;
	}
	return $dbh;
}
sub login{
	my $sock = shift;
	print "Logging in to socket\n";
	print $sock "Action: login${EOL}username: queue-manager${EOL}secret: ishohghi$BLANK";
#	print "Action: login${EOL}username: queue-manager${EOL}secret: ishohghi$BLANK";
	my $authmessage = <$sock>;
	$authmessage.= <$sock>;
	print $authmessage;
#Asterisk Call Manager/1.0
#Response: Success
#TODO Esto responde el server de Alvaro:	die "Could not authenticate to the socket interface: $authmessage.\n" if ($authmessage !~ /.*Response: Success\nMessage: Authentication accepted/);
	die "Could not authenticate to the socket interface: $authmessage.\n" if ($authmessage !~ /.*Response: Success.*/);
	print "Connected to socket\n";
}
login($sock);
#request_agents($sock);
#request_status($sock);
#open(LOG,"> abandon.log");
#open(LOG,"calltoqueue.log");
$dbh = opendb($dbh);
my $currentmessage = "";
#while (<LOG>)
my ($counter,$rate) = (0,128);#Print how many channels are opened each $rate events
while (<$sock>)
{
	#print LOG $_;
	if (/^$EOL/){
		$counter++;
		#print "\/***".$currentmessage."***\/\n";
		if ($currentmessage =~ /Event: Newchannel/){
			%channels = newChannel($currentmessage,%channels);
		}
		if ($currentmessage =~ /Event: Newstate/){#Usar newcallerid?
			%channels = newState($currentmessage,%channels);
		}
		if ($currentmessage =~ /Event: Join/){
			%channels = doJoin($currentmessage,$dbh,%channels);
		}
		if ($currentmessage =~ /Event: Link/){
			%channels = doLink($currentmessage,$dbh,%channels);
		}
		if ($currentmessage =~ /Event: Rename/){
			%channels = doRename($currentmessage,%channels);
		}
		if ($currentmessage =~ /Event: Hangup/){
			%channels = doHangup($currentmessage,%channels);
		}
		if ($currentmessage =~ /Event: QueueMemberPaused/){
			%channels = doPause($currentmessage,$dbh,%channels);	
		}
		if ($currentmessage =~ /Event: Agentcallbacklog/){
			%channels = doLogChange($currentmessage,$dbh,%channels);	
		}
		if ($currentmessage =~ /Event: Unlink/){
			%channels = doUnlink($currentmessage,$dbh,%channels);
		}
		if ($currentmessage =~ /Event: QueueCallerAbandon/){
			%channels = doAbandon($currentmessage,$dbh,%channels);
		}
		if ($currentmessage =~ /Event: Dial/){
			%channels = newDial($currentmessage,$dbh,%channels);
		}
		$currentmessage = "";
		if ($counter == $rate){
			print keys(%channels)." Channels open at the moment.\n";
			$counter = 0;
		}
	}else{
		$currentmessage.= $_;
	}
}
close(LOG);
while ( my ($key, $values) = each(%channels) ) {
	while ( my ($attribute, $value) = each(%{$values})){
		print "$key => $attribute => $value\n";
	}
}
# should never really come down here ...
close $sock;
$dbh = closedb($dbh);
#print $sock "Action: Logoff$BLANK";
exit(0);

