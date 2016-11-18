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
use Net::FTP;
use Getopt::Std;
use DBI;
use vars qw($dbh $export_type $dbhost $dbname $dbport $dbusername $dbpassword $verbose $parsefile $newline);
#IMPORTANT CONFIGURATION
$export_type = "DB";
#$export_type = "XML";
$dbname = "pbxreports";
$dbhost = "localhost";
$dbport = "3306";
$dbusername = "root";
$dbpassword = "greencore";
$newline = "\r";
$verbose = 0;
$parsefile = "0";
my $EOL = "\015\012";
my $BLANK = $EOL x 2;

my %channels = ();
my %params;
getopts("hH:p:u:Pv:F:", \%params);
if (exists $params{v}){
	$verbose = $params{v};
}
if (exists $params{H}){
	$dbhost = $params{H};
}
if (exists $params{p}){
	$dbport = $params{p};
}
if (exists $params{u}){
	$dbusername = $params{u};
}
if (exists $params{d}){
	$dbname = $params{d};
}
if (exists $params{F}){
	die ("File ".$params{F}." does not exists\n") if (! -e $params{F});
	die ("Could not read ".$params{F}."\n") if (! -r $params{F});
	die ("File ".$params{F}." is empty \n") if (-z $params{F});
	$parsefile = $params{F};
	$newline = "\n";
	$EOL = "\n";
	$BLANK = $EOL x 2;
}
if (exists $params{h}){
	print "amiparser.pl [OPTIONS]\n";
	print "\t-h:              Print this help and exit\n";
	print "\t-v <level>:      Verbose output level for debugging\n";
	print "\t-H <hostname>:   Database hostname\n";
	print "\t-p <port>:       Database port number\n";
	print "\t-u <username>:   Database Username\n";
	print "\t-d <database>:   Database name\n";
	print "\t-F <filename>:   Use the filename as the input from the socket\n";
	print "\t-P:              Prompt for password\n";
	exit;
}

#Check for the configured export type output posibility.
sub check_export_point{
	if ($export_type =~ /db/i){
		dbhconnect();
	}elsif($export_type =~ /xml/i){
		$dbh = "/var/spool/asterisk/monitor/";
		die "Could not open $dbh for output" if (!-w $dbh);
	}
}
sub channelInfo{
	my $channels = shift;
	while ( my ($key, $values) = each(%channels) ) {                                                                                                                                                                         
		while ( my ($attribute, $value) = each(%{$values})){
			print "\$channels{$key} => $attribute => $value\n";
		}
	}
}


sub dbhconnect {
	my $dsn = "DBI:mysql:database=$dbname;host=$dbhost;port=$dbport";
	$dbh =DBI->connect($dsn, $dbusername, $dbpassword) or die "Couldn't connect to DB ($dbname)...$dbh->errstr\n";
}

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
	print "Status finished\n";
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
	my ($uniqueid,%channels) = @_;
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
	}
}

sub closeTuple{
	opendb();
	my ($uniqueid,%channels) = @_;
	if ($verbose > 2){
		chomp(my $date = `date +'%Y-%m-%d %H:%M:%S'`);
		print "[$date] closeTuple: \$uniqueid = $uniqueid. \$DBID = ".(exists $channels{$uniqueid}{"DBID"}?$channels{$uniqueid}{"DBID"}:"unset").". src= ".(exists ($channels{$uniqueid}{"src"})?$channels{$uniqueid}{"src"}:"unset").". start_ts: ".(exists ($channels{$uniqueid}{"start_ts"})?$channels{$uniqueid}{"start_ts"}:"unset")."\n";
	}
        if (!exists($channels{$uniqueid}{"start_ts"}) || !exists($channels{$uniqueid}{"src"}) || !exists($channels{$uniqueid}{"DBID"})){
		return;
	}
	if (length($channels{$uniqueid}{"src"}) == 0){
		$channels{$uniqueid}{"src"} = "PRIVATE";
	}
	my $sth = "";
	my $sql = "UPDATE callinfo SET duration = (SELECT time_to_sec(timediff(now(),event_date)) FROM events WHERE id = ".$channels{$uniqueid}{"DBID"}.") WHERE eventid = ".$channels{$uniqueid}{"DBID"};
	$sth = $dbh->do($sql) or die $sth->errstr;
	return %channels;
}

sub dbXfer{
	opendb();
	my ($dstUniqueID,%channels) = @_;
	my $sth = "";
	my $date = "";
	if ($verbose > 2){
		chomp($date = `date +'%Y-%m-%d %H:%M:%S'`);
		print "[$date] dbXfer: \$dstUniqueID = $dstUniqueID. \$DBID = ".$channels{$dstUniqueID}{"DBID"}.". src= ".(exists ($channels{$dstUniqueID}{"src"})?$channels{$dstUniqueID}{"src"}:"unset").". start_ts: ".(exists ($channels{$dstUniqueID}{"start_ts"})?$channels{$dstUniqueID}{"start_ts"}:"unset")."\n";
	}
	my $sql = "INSERT INTO events(queue,agent,event_type,uniqueid) VALUES('".(exists($channels{$dstUniqueID}{"Queue"})?$channels{$dstUniqueID}{"Queue"}:"0")."','".$channels{$dstUniqueID}{"src"}."','xfer','".$channels{$dstUniqueID}{"Parent"}."')"; #Add a new event for the transfer
	$sth = $dbh->do($sql) or die $sth->errstr;
	my $id = $dbh->last_insert_id(undef, undef, qw(events id)) or die "no insert id?";
	$sql = "INSERT INTO callinfo(eventid,wait_time,src,dst) VALUES($id,0,'".$channels{$dstUniqueID}{"src"}."','".$channels{$dstUniqueID}{"dst"}."')";#Insert the new call to the callinfo table
	$sth = $dbh->do($sql) or die $sth->errstr;
	$channels{$dstUniqueID}{"DBID"} = $id;#Set a new DB Identifier
	if ($verbose > 2){
		print "[$date] dbXfer: \$dstUniqueID = $dstUniqueID. new \$DBID = ".$channels{$dstUniqueID}{"DBID"}.".\n";
	}
	return %channels;
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
	my ($data,%channels) = @_;	
#return %channels if ($data !~ /SrcUniqueID/);#This is a SubEvent Dial call such as Ending a call.
	return %channels;# We do not need this info at the moment
	my ($channel,$srcUniqueID,$dstUniqueID,$date) = ("") x 4;
	if ($data =~ /SrcUniqueID:\ (.*)$newline/){
		$srcUniqueID = $1;
	}
	if ($data =~ /DestUniqueID:\ (.*)$newline/){
		$dstUniqueID = $1;
	}
	if ($verbose > 2){
		chomp($date = `date +'%Y-%m-%d %H:%M:%S'`);
		print "[$date] newDial: \$srcUniqueid = $srcUniqueID. \$dstUniqueID = $dstUniqueID. start_ts: ".(exists ($channels{$srcUniqueID}{"start_ts"})?$channels{$srcUniqueID}{"start_ts"}:"unset")." (if unset Dial won't be processed)\n";
	}
	if (exists $channels{$srcUniqueID}{"start_ts"}){
		if ($verbose > 1){
			print "Xfer: Creating\n";
		}
		#Active call, this is a transfer
		my $dst = $channels{$dstUniqueID}{"Channel"};
		if ($dst =~ /.*\/(\d+)[@-].*/){
			$dst = $1;
		}
		#Clean the latest event duration
		$channels{$srcUniqueID}{"end_ts"} = time;
		$channels{$dstUniqueID}{"end_ts"} = time;
		if ($export_type =~ /db/i){
			%channels = closeTuple($srcUniqueID,%channels);
			%channels = dbXfer($srcUniqueID,%channels);
		}elsif ($export_type =~ /xml/i){
			createFile($srcUniqueID,%channels);
		}
		#Reset start_ts
		$channels{$srcUniqueID}{"start_ts"} = time;
		if ($verbose > 2){
			print "[$date] newDial: \$channels{$srcUniqueID}{\"dst\"}: $dst. Was ".(exists ($channels{$srcUniqueID}{"dst"})?$channels{$srcUniqueID}{"dst"}:"unset")." before. \$channels{$dstUniqueID}{\"dst\"} : $dst. Was ".(exists ($channels{$dstUniqueID}{"dst"})?$channels{$dstUniqueID}{"dst"}:"unset")." before\n";
		}
		$channels{$srcUniqueID}{"dst"} = $dst;
		$channels{$dstUniqueID}{"dst"} = $dst;
#		print "Xfer: Created\n";
	}
	return %channels;
}
#Event: Transfer
#Privilege: call,all
#TransferMethod: SIP
#TransferType: Attended
#Channel: SIP/3369-b2dff6e8
#Uniqueid: 1274407812.6037
#SIP-Callid: 4a5c7370-25e9311-57a9228e@192.168.160.33
#TargetChannel: SIP/3369-b33cd658
#TargetUniqueid: 1274407958.6041
sub newTransfer{
	my ($data,%channels) = @_;
	my ($srcUniqueID, $dstUniqueID) = ("") x 2;
	if ($data =~ /[^t]Uniqueid:\ (.*)$newline/){
		$srcUniqueID = $1;
	}
	if ($data =~ /TargetUniqueid:\ (.*)$newline/){
		$dstUniqueID = $1;
	}
	if ($verbose > 1){
		print "Transfer Event in progress\n";
	}
	chomp(my $date = `date +'%Y-%m-%d %H:%M:%S'`);
	if ($verbose > 2){
		print "[$date] newTransfer: \$srcUniqueID = $srcUniqueID. \$dstUniqueID = $dstUniqueID. start_ts: ".(exists ($channels{$srcUniqueID}{"start_ts"})?$channels{$srcUniqueID}{"start_ts"}:"unset")."\n";
	}
	#Clean the latest event duration
	$channels{$srcUniqueID}{"end_ts"} = time;
	$channels{$dstUniqueID}{"end_ts"} = time;
	if ($verbose > 2){
		print "[$date] newTransfer: \$channels{$srcUniqueID}{\"dst\"}: ".(exists($channels{$srcUniqueID}{"dst"})?$channels{$srcUniqueID}{"dst"}:"unset").". Was ".(exists($channels{$srcUniqueID}{"dst"})?$channels{$srcUniqueID}{"dst"}:"unset");#." before. \$channels{$dstUniqueID}{\"dst\"} : $channels{$dstUniqueID}{\"dst\"}. Was ".(exists ($channels{$dstUniqueID}{"dst"})?$channels{$dstUniqueID}{"dst"}:"unset")." before\n";
	}
	$channels{$dstUniqueID}{"Parent"} = (exists($channels{$srcUniqueID}{"Parent"})?$channels{$srcUniqueID}{"Parent"}:$srcUniqueID);#Set the parent, we check the srcUniqueID in case this call has been sent transferred several times
	if ($export_type =~ /db/i){
		%channels = closeTuple($srcUniqueID,%channels);
		%channels = dbXfer($dstUniqueID,%channels);
	}elsif ($export_type =~ /xml/i){
		createFile($srcUniqueID,%channels);
	}
	#Reset start_ts
	$channels{$srcUniqueID}{"start_ts"} = time;
#	$channels{$dstUniqueID}{"dst"} = $channels{$srcUniqueID}{"dst"};
#	print "Xfer: Created\n";
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
	if ($data =~ /Channel:\ (.*)$newline/){
		$channel = $1;
	}
	if ($data =~ /Uniqueid:\ (.*)$newline/){
		$uniqueid = $1;
	}
	if ($verbose > 2){
		chomp(my $date = `date +'%Y-%m-%d %H:%M:%S'`);
		print "[$date] newChannel: \$channels{$uniqueid}{\"Channel\"} = $channel\n";
	}
	$channels{$uniqueid}{"Channel"} = $channel;
	return %channels;
}
sub newState{
	my ($data,%channels) = @_;
	my ($callerid,$uniqueid) = ("") x 2;
	#print "DATA newState: $data\n";
	if ($data =~ /CallerIDNum:\ (.*)$newline/){
		$callerid = $1;
	}
	if ($data =~ /Uniqueid:\ (.*)$newline/){
		$uniqueid = $1;
	}
	if ($verbose > 2){
		chomp(my $date = `date +'%Y-%m-%d %H:%M:%S'`);
		print "[$date] newState: \$channels{$uniqueid}{\"src\"} = $callerid. It was ".(exists ($channels{$uniqueid}{"src"})?$channels{$uniqueid}{"src"}:"unset")." before.\n";
	}
	$channels{$uniqueid}{"src"} = $callerid;
	return %channels;
}
sub doJoin{
	my ($data,%channels) = @_;
	my ($queue,$uniqueid,$calleridname) = ("") x 3;
	if ($data =~ /Queue:\ (.*)$newline/){
		$queue = $1;
	}
	if ($data =~ /Uniqueid:\ (.*)$newline/){
		$uniqueid = $1;
	}
	if ($data =~ /CallerIDName:\ (.*)$newline/){
		$calleridname = $1;
	}
	if ($verbose > 2){
		chomp(my $date = `date +'%Y-%m-%d %H:%M:%S'`);
		print "[$date] doJoin: \$channels{$uniqueid}{\"Queue\"} = $queue. It was ".(exists ($channels{$uniqueid}{"Queue"})?$channels{$uniqueid}{"Queue"}:"unset")." before.\n";
		print "[$date] doJoin: \$channels{$uniqueid}{\"CallerIDName\"} = $calleridname. It was ".(exists ($channels{$uniqueid}{"CallerIDName"})?$channels{$uniqueid}{"CallerIDName"}:"unset")." before.\n";
	}
	$channels{$uniqueid}{"Queue"} = $queue;
	$channels{$uniqueid}{"start_ts"} = time;
	$channels{$uniqueid}{"CallerIDName"} = $calleridname;
	if ($export_type =~ /db/i){
		opendb();
		my $sql = "INSERT INTO events(queue,uniqueid) VALUES('$queue','$uniqueid')";
		my $sth;
		$sth = $dbh->do($sql) or die $sth->errstr;
		my $id = $dbh->last_insert_id(undef, undef, qw(events id)) or die "no insert id?";
		$channels{$uniqueid}{"DBID"} = $id;
	}
	return %channels;
}
#Event: Bridge
#Privilege: call,all
#Bridgestate: Link
#Bridgetype: core
#Channel1: Local/3305@from-queue-6ae1;2
#Channel2: SIP/3305-20a256c0
#Uniqueid1: 1271983101.84
#Uniqueid2: 1271983101.85
#CallerID1: 3303
#CallerID2: 3305
sub doLink{ #Bridge is equal to Link
	my ($data,%channels) = @_;
	my ($uniqueid1,$uniqueid2,$src,$dst) = ("") x 4;
	my $event_type = "inbound";
	if ($data =~ /Uniqueid1:\ (.*)$newline/){
		$uniqueid1 = $1;
	}
	if ($data =~ /Uniqueid2:\ (.*)$newline/){
		$uniqueid2 = $1;
	}
	if ($data =~ /CallerID1:\ (.*)$newline/){
		$src = $1;
	}
	if ($data !~ /Channel\d: Local/){# This is an outgoing call
		$event_type = "outbound";
		if ($data =~ /CallerID2:\ (.*)$newline/){
			$dst = $1;
		}
	}
	if ($data =~ /Channel2:\ .*\/(\d{2,})[-@].*$newline/){#for DAHDI
		$dst = $1;
	}
	my $date = "";
	if ($verbose > 2){
		chomp($date = `date +'%Y-%m-%d %H:%M:%S'`);
		print "[$date] doLink: \$uniqueid1 = $uniqueid1. \$uniqueid2 = $uniqueid2. \$src = $src. \$dst = $dst (if \$dst == \$src entry won't be processed).\n";
	}
	if ($dst ne $src){
		if ($verbose > 2){
			print "[$date] doLink: \$channels{$uniqueid1}{\"src\"} = $src. It was ".(exists ($channels{$uniqueid1}{"src"})?$channels{$uniqueid1}{"src"}:"unset")." before.\n";
			print "[$date] doLink: \$channels{$uniqueid2}{\"src\"} = $src. It was ".(exists ($channels{$uniqueid2}{"src"})?$channels{$uniqueid2}{"src"}:"unset")." before.\n";
		}
		$channels{$uniqueid1}{"start_ts"} = time if (!exists $channels{$uniqueid1}{"start_ts"});
		$channels{$uniqueid2}{"start_ts"} = time if (!exists $channels{$uniqueid2}{"start_ts"});
		$channels{$uniqueid1}{"src"} = $src;
		$channels{$uniqueid2}{"src"} = $src;
		if (length($dst) > 0){
			if ($verbose > 2){
				print "[$date] doLink: \$channels{$uniqueid1}{\"dst\"} = $dst. It was ".(exists ($channels{$uniqueid1}{"dst"})?$channels{$uniqueid1}{"dst"}:"unset")." before.\n";
				print "[$date] doLink: \$channels{$uniqueid2}{\"dst\"} = $dst. It was ".(exists ($channels{$uniqueid2}{"dst"})?$channels{$uniqueid2}{"dst"}:"unset")." before.\n";
			}
			if ($dst =~ /^81\d{10}/){
				$dst =~ s/^8//;
			}
			$event_type = "avaya" if ($dst =~ /^\d{3}$/);
			$event_type = "internal" if ($dst =~ /^3\d{3}$/ && $src =~ /^3\d{3}/);#Internal agents extensions are 3xxx
			$channels{$uniqueid1}{"dst"} = $dst;
			$channels{$uniqueid2}{"dst"} = $dst;
		}
		if ($export_type =~ /db/i){
			if (!exists $channels{$uniqueid1}{"DBID"} && exists($channels{$uniqueid1}{"Channel"}) && $channels{$uniqueid1}{"Channel"} !~ /Local.*/){#Not a call to/from the queue
				print "[$date] doLink: \$channels{$uniqueid1} Not a call to/from the queue.\n";
				my $sql = "INSERT INTO events(uniqueid,agent,event_type) VALUES('$uniqueid1','";
				my $agent = "0";#Agents are 4 digits extensions TODO exceptions
				if ($channels{$uniqueid1}{"src"} =~ /^\d{4}$/){
					$agent = $channels{$uniqueid1}{"src"};
				}elsif ($channels{$uniqueid1}{"dst"} =~ /^\d{4}$/){
					$agent = $channels{$uniqueid1}{"dst"};
				}
				$sql .= $agent."','$event_type')";
				opendb();
				my $sth;
				$sth = $dbh->do($sql) or die $sth->errstr;
				my $id = $dbh->last_insert_id(undef, undef, qw(events id)) or die "no insert id?";
				$channels{$uniqueid1}{"DBID"} = $id;
				$sql = "INSERT INTO callinfo(eventid,wait_time,src,dst) VALUES(".$channels{$uniqueid1}{"DBID"}.",(SELECT time_to_sec(timediff(now(),event_date)) FROM events WHERE id = ".$channels{$uniqueid1}{"DBID"}."),'$src','$dst');";
					$sth = $dbh->do($sql) or die $sth->errstr;
			}else{
				if (exists $channels{$uniqueid1} && exists $channels{$uniqueid1}{"DBID"} && exists $channels{$uniqueid1}{"Link"}){#Uniqueid1 has the insert ID
					opendb();
					#TODO cambiar src por dst si es outbound?#testing.
					my $sql = "UPDATE events SET agent = '$dst',event_type = '$event_type' WHERE id = ".$channels{$uniqueid1}{"DBID"};
					my $sth = "";
					$sth = $dbh->do($sql) or die $sth->errstr;
					$sql = "INSERT INTO callinfo(eventid,wait_time,src,dst) VALUES(".$channels{$uniqueid1}{"DBID"}.",(SELECT time_to_sec(timediff(now(),event_date)) FROM events WHERE id = ".$channels{$uniqueid1}{"DBID"}."),'$src','$dst');";
					$sth = $dbh->do($sql) or die $sth->errstr;
				}
			}
		}
	}
	if (exists $channels{$uniqueid1}) {
		if ($verbose > 2){
			print "[$date] doLink: \$channels{$uniqueid1}{\"Link\"} = $uniqueid2. It was ".(exists ($channels{$uniqueid1}{"Link"})?$channels{$uniqueid1}{"Link"}:"unset")." before.\n";
		}
		$channels{$uniqueid1}{"Link"} = $uniqueid2;
	}
	if (exists $channels{$uniqueid2}){
		if ($verbose > 2){
			print "[$date] doLink: \$channels{$uniqueid2}{\"Link\"} = $uniqueid1. It was ".(exists ($channels{$uniqueid2}{"Link"})?$channels{$uniqueid2}{"Link"}:"unset")." before.\n";
		}
		$channels{$uniqueid2}{"Link"} = $uniqueid1;
	}
	return %channels;
}

sub doUnlink{
	my ($data,%channels) = @_;
	my ($uniqueid1,$uniqueid2) = ("") x 2;
	if ($data =~ /Uniqueid1:\ (.*)$newline/){
		$uniqueid1 = $1;
	}
	if ($data =~ /Uniqueid2:\ (.*)$newline/){
		$uniqueid2 = $1;
	}
	if (exists($channels{$uniqueid1})){
		$channels{$uniqueid1}{"end_ts"} = time;
		if (exists($channels{$uniqueid2})){
			$channels{$uniqueid2}{"end_ts"} = $channels{$uniqueid1}{"end_ts"};
		}
	}
	return %channels;
}
sub doPause{
	my ($data,%channels) = @_;
	my ($queue,$membername,$pausebool) = ("") x 3;
	if ($data =~ /Queue:\ (.*)$newline/){
		$queue = $1;
	}
	if ($data =~ /MemberName:\ Agent\/(.*)$newline/){
		$membername = $1;
	}
	if ($data =~ /Paused:\ (.*)$newline/){
		$pausebool = $1;
	}
	if ($pausebool eq "1"){
		$pausebool = "pause_start";
	}else{
		$pausebool = "pause_end";
	}
	if ($verbose > 2){
		print "doPause: \$queue = $queue. \$membername = $membername. \$pausebool = $pausebool\n.";
	}
	if ($export_type =~ /db/i){
		opendb();
		my $sql = "INSERT INTO events(queue,agent,event_type) VALUES('$queue','$membername','$pausebool')";
		my $sth;
		$sth = $dbh->do($sql) or die $sth->errstr;
	}
	return %channels;
}
#TODO Membername might not be called in 1.6
sub doLogChange{
	my ($data,%channels) = @_;
	my ($queue,$membername,$pausebool) = ("") x 3;
	#Logintime: 34087
	if ($data =~ /Queue:\ (.*)$newline/){
		$queue = $1;
	}
	#Agent: 4400
	if ($data =~ /MemberName:\ Agent\/(.*)$newline/){
		$membername = $1;
	}
	if ($data =~ /Paused:\ (.*)$newline/){
		$pausebool = $1;
	}
	if ($data =~ /Event: Agentcallbacklogoff/){
		$pausebool = "logoff";
	}else{
		$pausebool = "login";
	}
	if ($verbose > 2){
		chomp(my $date = `date +'%Y-%m-%d %H:%M:%S'`);
		print "[$date] doLogChange: \$queue = $queue. \$membername = $membername. \$pausebool = $pausebool.\n";
	}
	opendb();
	my $sql = "INSERT INTO events(queue,agent,event_type) VALUES('$queue','$membername','$pausebool')";
	my $sth;
	$sth = $dbh->do($sql) or die $sth->errstr;
	return %channels;
}
sub doAbandon{
	my ($data,%channels) = @_;
	my ($uniqueid,$holdtime) = ("",0);
	if ($data =~ /Uniqueid:\ (\d*\.\d*)$newline/){
		$uniqueid = $1;
	}
	if ($data =~ /HoldTime:\ (\d*)$newline/){
		$holdtime = $1;
	}
	if ($verbose > 2){
		chomp(my $date = `date +'%Y-%m-%d %H:%M:%S'`);
		print "[$date] doAbandon: \$uniqueid = $uniqueid. \$holdtime = $holdtime.\n";
	}
	if ($export_type =~ /db/i && exists($channels{$uniqueid}{"DBID"})){
		opendb();
		my $sql = "UPDATE events SET event_type = 'abandon' WHERE id = ".$channels{$uniqueid}{"DBID"}.";";
		my $sth;
		$sth = $dbh->do($sql) or die $sth->errstr;
		$sql = "INSERT INTO callinfo(eventid,wait_time,duration,src) VALUES(".$channels{$uniqueid}{"DBID"}.",$holdtime,0,'".(exists($channels{$uniqueid}{"src"})?$channels{$uniqueid}{"src"}:"Unknown")."');";
		$sth = $dbh->do($sql) or die $sth->errstr;
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
	if ($data =~ /[^w]Uniqueid:\ (.*)$newline/){
		$uniqueid = $1;
	}
	if ($data =~ /NewUniqueid:\ (.*)$newline/){
		$newUniqueid = $1;
		if ($verbose > 2){
			chomp(my $date = `date +'%Y-%m-%d %H:%M:%S'`);
			print "[$date] doRename: \$uniqueid = $uniqueid. \$newUniqueid = $newUniqueid.\n";
		}
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
	if ($data =~ /Uniqueid:\ (.*)$newline/){
		$uniqueid = $1;
		if (exists( $channels{$uniqueid})){
			if ($export_type =~ /xml/i){
				createFile($dbh,$uniqueid,%channels);
			}elsif($export_type =~ /db/i && exists($channels{$uniqueid}{"DBID"})){
				opendb();
				my $sql = "UPDATE callinfo SET duration = (SELECT time_to_sec(timediff(now(),event_date)) FROM events WHERE id = ".$channels{$uniqueid}{"DBID"}.") WHERE eventid = ".$channels{$uniqueid}{"DBID"};
				if ($verbose > 2){
					chomp(my $date = `date +'%Y-%m-%d %H:%M:%S'`);
					print "[$date] doHangup: \$uniqueid = $uniqueid. \$DBID = ".$channels{$uniqueid}{"DBID"}.".\n";
				}
				my $sth = "";
				$sth = $dbh->do($sql) or die $sth->errstr;
			}
			while ( my ($attribute, $value) = each(%{$channels{$uniqueid}})){
				delete $channels{$uniqueid}{$attribute};
			}
			if ($verbose > 1){
				print "Cleaning \$channels{$uniqueid}\n";
			}
			delete $channels{$uniqueid};
		}
	}
	return %channels;
}
sub opendb {
	if ( ! $dbh ) {
		dbhconnect();
	}elsif ( ! $dbh->ping ) {
		dbhconnect();
	}
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
	print $sock "Action: login${EOL}username: queue-manager${EOL}secret: ishohghi$BLANK";
#	print "Action: login${EOL}username: queue-manager${EOL}secret: ishohghi$BLANK";
	my $authmessage = <$sock>;
	$authmessage.= <$sock>;
	print $authmessage;
#Asterisk Call Manager/1.0
#Response: Success
	chomp(my $date = `date +'%Y-%m-%d %H:%M:%S'`);
	if ($authmessage !~ /.*Response: Success.*/){
		print "[$date]: Could not authenticate to the socket interface: $authmessage.\n";
		return 1;
	}else{
		print "[$date]: Connected to socket\n";
		return 0;
	}
}
check_export_point();
my $sock;
if ($parsefile eq "0"){
	$sock = new IO::Socket::INET ( PeerAddr => 'localhost', PeerPort => '5038', Proto => 'tcp', Reuse => 1); 
}else{
	open($sock, "<", $parsefile) or die $!;
}
#request_agents($sock);
#request_status($sock);
my $log;
if ($parsefile eq "0"){
	open($log, ">>", "amiparser.log") or die $!;
}
#open(LOG,"parser.log");
my $currentmessage = "";
my $date = "";
my ($counter,$rate) = (0,128);#Print how many channels are opened each $rate events
while (1){
	if ($parsefile eq "0"){
		print "Logging in to socket\n";
		while (login($sock) > 0){
			print "Could not connect to socket, attempting to reconect in 5 seconds\n";
			sleep(5);
		}
	}
	while (<$sock>){
		if (/^$EOL/){
			$counter++;
			if ($verbose > 1 && $parsefile eq "0"){
				$date = `date +'%Y-%m-%d %H:%M:%S'`;
				print $log "\n\n".$date;
				print $log $currentmessage;
			}
			#print "\/***".$currentmessage."***\/\n";
			if ($currentmessage =~ /Event: Newchannel/){
				print "CALLING newChannel()\n" if ($verbose > 2);
				%channels = newChannel($currentmessage,%channels);
			}
			if ($currentmessage =~ /Event: Newstate/){#Usar newcallerid?
				print "CALLING newState()\n" if ($verbose > 2);
				%channels = newState($currentmessage,%channels);
			}
			if ($currentmessage =~ /Event: Join/){
				print "CALLING doJoin()\n" if ($verbose > 2);
				%channels = doJoin($currentmessage,%channels);
				sleep(1) if ($parsefile ne "0");#Just making calls from the parser not be all with duration 0.
			}
			if ($currentmessage =~ /Event: Link/|| $currentmessage =~ /Event: Bridge/){
				sleep(1) if ($parsefile ne "0");#Just making calls from the parser not be all with duration 0.
				print "CALLING doLink()\n" if ($verbose > 2);
				%channels = doLink($currentmessage,%channels);
			}
			if ($currentmessage =~ /Event: Rename/){
				print "CALLING doRename()\n" if ($verbose > 2);
				%channels = doRename($currentmessage,%channels);
			}
			if ($currentmessage =~ /Event: Hangup/){
				print "CALLING doHangup()\n" if ($verbose > 2);
				%channels = doHangup($currentmessage,%channels);
			}
			if ($currentmessage =~ /Event: QueueMemberPaused/){
				print "CALLING doPause()\n" if ($verbose > 2);
				%channels = doPause($currentmessage,%channels);
			}
			if ($currentmessage =~ /Event: Agentcallbacklog/){
				print "CALLING doLogChange()\n" if ($verbose > 2);
				%channels = doLogChange($currentmessage,%channels);
			}
			if ($currentmessage =~ /Event: Unlink/){
				print "CALLING doUnlink()\n" if ($verbose > 2);
				%channels = doUnlink($currentmessage,%channels);
			}
			if ($currentmessage =~ /Event: Transfer/){
				print "CALLING newTransfer()\n" if ($verbose > 2);
				%channels = newTransfer($currentmessage,%channels);
			}
			if ($currentmessage =~ /Event: QueueCallerAbandon/){
				print "CALLING doAbandon()\n" if ($verbose > 2);
				%channels = doAbandon($currentmessage,%channels);
			}
			if ($currentmessage =~ /Event: Dial/){
				print "CALLING newDial()\n" if ($verbose > 2);
				%channels = newDial($currentmessage,%channels);
				sleep(1) if ($parsefile ne "0");#Just making calls from the parser not be all with duration 0.
			}
			$currentmessage = "";
			if ($counter == $rate && $verbose > 0){
				print keys(%channels)." Channels open at the moment.\n";
				channelInfo(%channels);
				$counter = 0;
			}
		}else{
			$currentmessage.= $_;
		}
	}
	if ($parsefile eq "0"){
		print "Disconnected from socket, attempting to reconnect in 5 seconds\n";
		sleep(5);
		$sock = new IO::Socket::INET ( PeerAddr => 'localhost', PeerPort => '5038', Proto => 'tcp', Reuse => 1); 
		print "Could not create socket: $!\n" unless $sock;
	}else{
		close($sock);
		exit 0;
	}
}
# should never really come down here ...
close $sock;
$dbh = closedb($dbh);
#print $sock "Action: Logoff$BLANK";
exit(0);

