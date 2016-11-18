<?
	
#We're gonna be having all the reports here.
#Some reports will have the same layout so we can just display the same grid when possible.
#TODO check dst on basicStoreTable

#This basic store table will be used by the inbound call history
function basicStoreTable(){
?>
			<table dojoType="dojox.grid.DataGrid" jsId="report"  id="agentGridNode">
			<thead>
				<tr>
<?				if ($_REQUEST['report_type'] == "xfer"){?>
					<th field="src" width="auto">Caller</th>
					<th field="agent" width="auto">Agent</th>
					<th field="queue" width="auto">Queue</th>
					<th field="dst" width="auto">Destination</th>
					<th field="wait_time" width="auto">Wait Time</th>
<?				}else{?>
<?					if ($_REQUEST['report_type'] != "outbound"){?>
						<th field="src" width="auto">Source</th>
						<th field="agent" width="auto">Agent</th>
						<th field="queue" width="auto">Queue</th>
						<th field="dst" width="auto">Destination</th>
						<th field="wait_time" width="auto">Wait Time</th>
<?					}else{?>
						<th field="agent" width="auto">Caller</th>
						<th field="dst" width="auto">Destination</th>
<?					}
				}?>
				<th field="event_date" width="auto">Date</th>
				<th field="duration" width="auto">Duration</th>
				</tr>
			</thead>
			</table>
		<script type="text/javascript">
			dojo.byId("reportinfo").innerHTML = "<strong> Reporting <?echo ($_REQUEST['report_type'] == "xfer"?"Transfer":$_REQUEST['report_type']);?> Grid: </strong>";
			dojo.animateProperty({ node: "reportinfo",duration: 2000,properties: {backgroundColor: { start: "#FFFFFF", end: '#EEFFEE'}}}).play();
		</script>
<?}
#This is the definition for the queue status table
function queueStatsStoreTable(){
?>
			<table dojoType="dojox.grid.DataGrid" jsId="report"  id="queueGridNode">
			<thead>
				<tr>
				<th field="queue" width="auto">Queue</th>
				<th field="abandon" width="auto">Abandon Calls</th>
				<th field="abandonpercent" width="auto">Abandon Percent</th>
				<th field="inbound" width="auto">Inbound Calls</th>
				<th field="inboundpercent" width="auto">Inbound Percent</th>
				<th field="outbound" width="auto">Outbound Calls</th>
				<th field="outboundpercent" width="auto">Outbound Percent</th>
				<th field="xfer" width="auto">Transfers Calls</th>
				<th field="xferpercent" width="auto">Transfer Percent</th>
				<th field="internal" width="auto">Internal Calls</th>
				<th field="internalpercent" width="auto">Internal Percent</th>
				<th field="totalcalls" width="auto">Total Calls</th>
				</tr>
			</thead>
			</table>
		<script type="text/javascript">
			dojo.byId("reportinfo").innerHTML = "<strong> Reporting Queue Stats Grid: </strong>";
			dojo.animateProperty({ node: "reportinfo",duration: 2000,properties: {backgroundColor: { start: "#FFFFFF", end: '#EEFFEE'}}}).play();
		</script>
<?}

#This basic store table will be used by the transfer call history
function transferStoreTable(){
?>
			<table dojoType="dojox.grid.DataGrid" store"reportstore" jsId="report"  id="agentGridNode">
			<thead>
				<tr>
				<th field="src" width="auto">Original Caller</th>
				<th field="dst" width="auto">Destination</th>
				<th field="queue" width="auto">Original Queue</th>
				<th field="agent" width="auto">Original Agent</th>
				<th field="duration" width="auto">Duration</th>
				<th field="event_date" width="auto">Date</th>
				</tr>
			</thead>
			</table>
		<script type="text/javascript">
			dojo.byId("reportinfo").innerHTML = "<strong> Reporting <?echo $_REQUEST['report_type'];?> Grid: </strong>";
			dojo.animateProperty({ node: "reportinfo",duration: 2000,properties: {backgroundColor: { start: "#FFFFFF", end: '#EEFFEE'}}}).play();
		</script>
<?}
#This basic store table will be used by the abandon call history
function abandonStoreTable(){
?>
			<table dojoType="dojox.grid.DataGrid" jsId="report"  id="agentGridNode">
			<thead>
				<tr>
				<th field="src" width="25%">Caller</th>
				<th field="queue" width="25%">Queue</th>
				<th field="wait_time" width="25%">Wait Time</th>
				<th field="event_date" width="25%">Date</th>
				</tr>
			</thead>
			</table>
		<script type="text/javascript">
			dojo.byId("reportinfo").innerHTML = "<strong> Reporting <?echo $_REQUEST['report_type'];?> Grid: </strong>";
			dojo.animateProperty({ node: "reportinfo",duration: 2000,properties: {backgroundColor: { start: "#FFFFFF", end: '#EEFFEE'}}}).play();
		</script>
<?}
#Define the calldetailgrid layout
function callDetailGrid(){?>
	<table dojoType="dojox.grid.TreeGrid" class="grid" jsId="report" defaultOpen="false" rowsPerPage="20">
	<thead>
	<tr>
		<th field="src" width="20%">Caller</th>
		<th field="events" aggregates="sum" itemAggregates="totIndate,totType,totQueue,totAgents,totWaittime,totDuration,totDst">
			<table> 
			<thead>
			<tr>
				<th field="indate" width="11%">Date</th>
				<th field="event_type" width="6%">Type</th>
				<th field="queue" width="10%">Queue</th>
				<th field="agent" width="10%">Agent</th>
				<th field="waittime" width="6%" formatter="formatHHMMSS">Wait Time</th>
				<th field="seconds" width="6%" formatter="formatHHMMSS">Duration</th>
				<th field="dst" width="20%">Destination</th>
			</tr>
			</thead>
			</table>
		</th>
	</tr>
	</thead>
	</table>
	<script type="text/javascript">
		dojo.byId("reportinfo").innerHTML = "<strong> Call Detail Report Grid: </strong>";
		dojo.animateProperty({ node: "reportinfo",duration: 2000,properties: {backgroundColor: { start: "#FFFFFF", end: '#EEFFEE'}}}).play();
	</script>
<?}
#Define the agentdetailgrid layout
function agentDetail(){?>
	<table dojoType="dojox.grid.TreeGrid" class="grid" jsId="report" sortChildItems="true" defaultOpen="false" rowsPerPage="20">
	<thead>
	<tr>
		<th field="agent" width="30%">Agent</th>
		<th field="calls" aggregates="sum" itemAggregates="totQueue,totIndate,totType,totWaittime,totDurationText,totDst">
			<table> 
			<thead>
			<tr>
				<th field="queue" width="12%">Queue</th>
				<th field="event_date" width="12%">Date</th>
				<th field="event_type" width="12%">Type</th>
				<th field="wait_time"  width="12%" formatter="formatHHMMSS">Wait Time</th>
				<th field="duration"  width="12%" formatter="formatHHMMSS">Duration</th>
				<th field="dst" width="10%">Talked To</th>
			</tr>
			</thead>
			</table>
		</th>
	</tr>
	</thead>
	</table>
	<script type="text/javascript">
		dojo.byId("reportinfo").innerHTML = "<strong>Agent Detail Report Grid: </strong>";
		dojo.animateProperty({ node: "reportinfo",duration: 2000,properties: {backgroundColor: { start: "#FFFFFF", end: '#EEFFEE'}}}).play();
	</script>
<?}
function unknown(){?>
	<strong>Unknown report_type.</strong>
	The option chosen does not match any report type. Please refresh your browser.
	<script type="text/javascript">
		dojo.animateProperty({ node: "reportinfo",duration: 2000,properties: {backgroundColor: { start: "#FFFFFF", end: '#EEFFEE'}}}).play();
	</script>
<?}
$report_type = (isset($_REQUEST['report_type'])?$_REQUEST['report_type']:"calldetail");
switch($report_type){
	case "calldetail":
		callDetailGrid();
		break;
	case "agentdetail":
		agentDetail();
		break;
	case "queuestats":
		queueStatsStoreTable();
		break;
	case "abandon":
		abandonStoreTable();
		break;
	case "xfer":
	case "outbound":
	case "inbound":
		basicStoreTable();
		break;
	case "test":
	default:
		unknown();
}

?>
