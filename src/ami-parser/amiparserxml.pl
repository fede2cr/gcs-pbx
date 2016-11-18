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
use warnings;
use IO::Socket;
use CGI qw(:standard);
#use Net::FTP;
use DBI;
my $dbh = "/var/spool/asterisk/monitor/";
die "Could not open $dbh for output" if (!-w $dbh);
my ($counter,$rate) = (0,128);#Print how many channels are opened each $rate events

my $EOL = "\015\012";
my $BLANK = $EOL x 2;

my $sock = new IO::Socket::INET ( PeerAddr => 'localhost', PeerPort => '5038', Proto => 'tcp', Reuse => 1); 
die "Could not create socket: $!\n" unless $sock;

my %channels = ();

sub sendFTP{
	my $filename = shift;
	my $ftphost = "172.31.0.252";
	my $ftpUsername = "rftp";
	my $ftpPassword = "rftp999";
	my $ftp = Net::FTP->new($ftphost, Timeout => 5, Debug => 0) or die "Cannot connect to $ftphost: $@";;
	$ftp->login($ftpUsername,$ftpPassword) or die("couldn't log in: $@");
	$ftp->type('I') or die("couldn't set binary mode");
	$ftp->put($filename) or die("Couldn't send file");
	$ftp->quit();
}
sub request_agents{ 
	print "Requesting Agents\n";
	my $sock = shift;
	print $sock "Action: Agents$BLANK";
	my %item = ();
	while (<$sock>){
		print $_;
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
		last if (/^Event: StatusComplete/);
	}
}

sub XMLEntities{
	my $str = shift;
	return "" if (length($str) == 0);
	$str =~ s/</&lt;/;
	$str =~ s/>/&gt;/;
	$str =~ s/&/&amp;/;
	$str =~ s/\"/&quot;/;
	$str =~ s/\'/&apos;/;
	return $str;
}

sub createFile{ 
	my $date = 0;
	my ($dbh,$uniqueid,%channels) = @_;
	my $recording_tag = "Unknown";
	if (!exists($channels{$uniqueid}{"start_ts"}) || !exists($channels{$uniqueid}{"src"})){
		return;
	}
	if (length($channels{$uniqueid}{"src"}) == 0){
		$channels{$uniqueid}{"src"} = "PRIVATE";
	}
	if (length($channels{$uniqueid}{"src"})){
		$recording_tag = $channels{$uniqueid}{"src"};
	}
	if ($recording_tag =~ /(.*)\ <.*>/){#remove the trailing \ <2001>
		$recording_tag = $1;
	}
	my $content = "<recording_info>\n";
	$content .= "<recording_tag>".XMLEntities($recording_tag)."</recording_tag>\n";
	$content .= "<recorded_call_id>206027</recorded_call_id>\n";
	$content .= "<recorder_cid></recorder_cid>\n";
	$content .= "<recorded_cid>".XMLEntities($channels{$uniqueid}{"src"})."</recorded_cid>\n";
	$content .= "<recorder_account_id></recorder_account_id>\n";
	$content .= "<recorded_account_id>".XMLEntities(exists($channels{$uniqueid}{"Queue"})?$channels{$uniqueid}{"Queue"}:"")."</recorded_account_id>\n";
	$content .= "<from_account_id>".XMLEntities($channels{$uniqueid}{"Queue"})."</from_account_id>\n";
	$content .= "<from_caller_id>".XMLEntities($channels{$uniqueid}{"src"})."</from_caller_id>\n";
	$content .= "<to_account_id>".((exists($channels{$uniqueid}{"Link"}) && exists($channels{$channels{$uniqueid}{"Link"}}{"Queue"}))?XMLEntities($channels{$channels{$uniqueid}{"Link"}}{"Queue"}):"-1")."</to_account_id>\n";
	$content .= "<to_caller_id>".XMLEntities($channels{$uniqueid}{"dst"})."</to_caller_id>\n";
	$content .= "<duration>".($channels{$uniqueid}{"end_ts"} - $channels{$uniqueid}{"start_ts"})."</duration>\n";   
	my ($sec, $min, $hour, $day,$month,$year) = (localtime($channels{$uniqueid}{"start_ts"}))[0,1,2,3,4,5,6]; 
	$month++;
	$content .= "<date_created_ts>".($year + 1900)."-".($month <= 9?0:"")."$month-".($day <= 9?0:"")."$day ".($hour <= 9?0:"")."$hour:".($min <= 9?0:"")."$min:".($sec <= 9?0:"")."$sec.0</date_created_ts>\n";
	$content .= "<date_created_secs>".$channels{$uniqueid}{"start_ts"}."</date_created_secs>\n";
	$content .= "</recording_info>\n";
	my $filename = "".($year + 1900)."-".($month <= 9?0:"")."$month-".($day <= 9?0:"")."$day-".($hour <= 9?0:"")."$hour-".($min <= 9?0:"")."$min-".($sec <= 9?0:"")."$sec";
	$filename .= "_".XMLEntities($channels{$uniqueid}{"src"})."_".XMLEntities($channels{$uniqueid}{"dst"});
	open(my $outputfile,">","$dbh$filename.xml");
	print $outputfile $content;
	close($outputfile);
	my @files = <$dbh*$uniqueid*>;
	foreach my $file (@files) { 
		print "Renaming ".$file." to $dbh$filename.wav\n";
		rename("$file","$dbh$filename.wav");
#		sendFTP("$dbh$filename.wav");
#		sendFTP("$dbh$filename.xml");
	}
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
	if (exists $channels{$srcUniqueID}{"start_ts"}){
		#print "Xfer: Creating\n";
		#Active call, this is a transfer
		my $dst = $channels{$dstUniqueID}{"Channel"};
		if ($dst =~ /.*\/(\d+)[@-].*/){
			$dst = $1;
		}
		$channels{$srcUniqueID}{"end_ts"} = time;#Reset the start_time
		$channels{$srcUniqueID}{"end_ts"} = time;#Reset the start_time
		createFile($dbh,$srcUniqueID,%channels);
		$channels{$srcUniqueID}{"start_ts"} = time;
		$channels{$srcUniqueID}{"dst"} = $dst;
		$channels{$dstUniqueID}{"dst"} = $dst;
		#print "Xfer: Created\n";
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
	my ($callerid,$uniqueid) = ("") x 2;
	#print "DATA newState: $data\n";
	if ($data =~ /CallerID:\ (.*)\r/){
		$callerid = $1;
	}
	if ($data =~ /Uniqueid:\ (.*)\r/){
		$uniqueid = $1;
	}
	$channels{$uniqueid}{"src"} = $callerid;
	return %channels;
}
sub doJoin{
	my ($data,$dbh,%channels) = @_;
	my ($queue,$uniqueid,$calleridname) = ("") x 3;
	#print "DATA: $data";
	if ($data =~ /Queue:\ (.*)\r/){
		$queue = $1;
	}
	if ($data =~ /Uniqueid:\ (.*)\r/){
		$uniqueid = $1;
	}
	if ($data =~ /CallerIDName:\ (.*)\r/){
		$calleridname = $1;
	}
	$channels{$uniqueid}{"Queue"} = $queue;
	$channels{$uniqueid}{"start_ts"} = time;
	$channels{$uniqueid}{"CallerIDName"} = $calleridname;
	return %channels;
}
sub doLink{
	my ($data,$dbh,%channels) = @_;
	my ($uniqueid1,$uniqueid2,$src,$dst) = ("") x 4;
	#print "DATA: $data";
	if ($data =~ /Uniqueid1:\ (.*)\r/){
		$uniqueid1 = $1;
	}
	if ($data =~ /Uniqueid2:\ (.*)\r/){
		$uniqueid2 = $1;
	}
	if ($data =~ /CallerID1:\ (.*)\r/){
		$src = $1;
	}
	if ($data !~ /Channel\d: Local/){# This is an outgoing call
		if ($data =~ /CallerID2:\ (.*)\r/){
			$dst = $1;
		}
	}
	if ($data =~ /Channel2:\ .*\/(\d{2,})[-@].*\r/){
		$dst = $1;
	}
	if ($dst ne $src){
		$channels{$uniqueid1}{"start_ts"} = time if (!exists $channels{$uniqueid1}{"start_ts"});
		$channels{$uniqueid2}{"start_ts"} = time if (!exists $channels{$uniqueid2}{"start_ts"});
		$channels{$uniqueid1}{"src"} = $src;
		$channels{$uniqueid2}{"src"} = $src;
		if (length($dst) > 0){
			$channels{$uniqueid1}{"dst"} = $dst;
			$channels{$uniqueid2}{"dst"} = $dst;
		}else{
			channelInfo(%channels);
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
	if (exists($channels{$uniqueid1})){#Uniqueid1 has the first insert
		$channels{$uniqueid1}{"end_ts"} = time;
		if (exists($channels{$uniqueid2})){
			$channels{$uniqueid2}{"end_ts"} = $channels{$uniqueid1}{"end_ts"};
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
				$channels{$newUniqueid}{$attribute} = $channels{$uniqueid}{$attribute};
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
		if (exists($channels{$uniqueid})){
			createFile($dbh,$uniqueid,%channels);
			while ( my ($attribute, $value) = each(%{$channels{$uniqueid}})){
				delete $channels{$uniqueid}{$attribute};
			}
			print "Deleted \$channels{$uniqueid}\n";
			delete $channels{$uniqueid};
		}
	}
	return %channels;
}
sub login{
	my $sock = shift;
	print "Logging in to socket\n";
	print $sock "Action: login${EOL}username: queue-manager${EOL}secret: ishohghi$BLANK";
#	print "Action: login${EOL}username: queue-manager${EOL}secret: ishohghi$BLANK";
	my $authmessage = <$sock>;
	$authmessage.= <$sock>;
	print $authmessage;
	die "Could not authenticate to the socket interface: $authmessage.\n" if ($authmessage !~ /.*Response: Success.*/);
	print "Connected to socket\n";
}
sub channelInfo{
	my $channels = shift;
	while ( my ($key, $values) = each(%channels) ) {
		while ( my ($attribute, $value) = each(%{$values})){
			print "\$channels{$key} => $attribute => $value\n";
		}
	}
}

login($sock);
my $currentmessage = "";
while (<$sock>){
	if (/^$EOL/){
		$counter++;
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
close $sock;
#print $sock "Action: Logoff$BLANK";
exit(0);
