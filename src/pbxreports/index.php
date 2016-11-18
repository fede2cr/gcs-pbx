<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head><title>PBX Reports</title>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<script type="text/javascript" src="../dojo/dojo/dojo.js" djConfig="parseOnLoad:true"></script>
<script type="text/javascript" src="../dojo/dojo/gcs-dojo.js"></script>
<script type="text/javascript" src="../dojo/dijit/dijit.js"></script>
<script type="text/javascript">
	dojo.require("dojo.parser");
	dojo.require("dijit.dijit");
	dojo.require("dijit.layout.AccordionContainer");
	dojo.require("dijit.layout.BorderContainer");
	dojo.require("dijit.layout.ContentPane");
	dojo.require("dijit.layout.StackContainer");
	dojo.require("dijit.form.Form");
	dojo.require("dijit.form.TextBox");
	dojo.require("dijit.form.FilteringSelect");
	dojo.require("dijit.form.Button");
	dojo.require("dijit.form.TextBox");
	dojo.require("dijit.form.ValidationTextBox");
	dojo.require("dijit.InlineEditBox");
	dojo.require("dijit.form.DateTextBox");
	dojo.require("dijit.form.HorizontalSlider");
	dojo.require("dijit.form.HorizontalRule");
	dojo.require("dijit.form.HorizontalRuleLabels");
	dojo.require("dijit.form.Select");
	dojo.require("dijit.Tooltip");
	dojo.require("dojox.grid.DataGrid");
	dojo.require("dojo.data.ItemFileReadStore");
	dojo.require("dojox.layout.ContentPane");
	dojo.require("dojo.fx");
	dojo.require("dojox.grid.TreeGrid");
	dojo.require("dijit.form.Textarea");
	dojo.require("dijit.Menu");
	var currentreport = "calldetail";
	var calcTotals = function(items,request){
		var totDuration = 0;
		var totEntries = 0;
		var totAbandons = 0;
		var totWaittime = 0;
		var totInbounds = 0;
		var totOutbounds = 0;
		var totAbandonHoldTime = 0;
		var totTransfers = 0;
		for (var i = 0; i < (items.length); i++){
			switch(currentreport){
				case "calldetail":
					totDuration += returnFloat(items[i].totDuration[0]);
					totWaittime += returnFloat(items[i].totWaittime[0]);
					for (var j = 0; j < items[i].events.length; j++){
						switch(items[i].events[j].event_type[0]){
							case "inbound":
								totInbounds++;
								break;
							case "outbound":
								totOutbounds++;
								break;
							case "abandon":
								totAbandons++;
								break;
							case "xfer":
								totTransfers++;
								break;
						}
						totEntries++;
					}
					break;
				case "queuestats":
					totOutbounds += returnFloat(items[i].outbound[0]);
					totInbounds += returnFloat(items[i].inbound[0]);
					totAbandons += returnFloat(items[i].abandon[0]);
					totTransfers += returnFloat(items[i].xfer[0]);
					totEntries += returnFloat(items[i].totalcalls[0]);
					break;
				case "agentdetail":
					totDuration += returnFloat(items[i].totDuration[0]);
					totWaittime += returnFloat(items[i].totWaittime[0]);
					for (var j = 0; j < items[i].calls.length; j++){
						switch(items[i].calls[j].event_type[0]){
							case "inbound":
								totInbounds++;
								break;
							case "outbound":
								totOutbounds++;
								break;
							case "abandon":
								totAbandons++;
								break;
							case "xfer":
								totTransfers++;
								break;
						}
						totEntries++;
					}
					break;
				case "abandon":
					totWaittime += returnFloat(items[i].wait_time[0]);
					totEntries++;
					break;
				case "xfer":
				case "inbound":
				default:
					totDuration += returnFloat(items[i].duration[0]);
					totWaittime += returnFloat(items[i].wait_time[0]);
					totEntries++;
					break;
			}
		}
		dojo.byId("totals").innerHTML = "<table><tbody><tr><td>Total calls: </td><td><b>"+totEntries+"</b></td><td>Total Abandonned Calls:</td><td><b>"+totAbandons+"</b></td><td>Total Transfers:</td><td><b>"+totTransfers+"</b></td><td>Total Duration</td><td><b>"+formatHHMMSS(totDuration)+"</b></td><td>Total Wait Time</td><td><b>"+formatHHMMSS(totWaittime)+"</b></td></tr></tbody></table>";
	}
	function setGeneratedTime(){
		var currentTime = new Date();
		var hours = currentTime.getHours();
		var minutes = currentTime.getMinutes();
		var month = currentTime.getMonth() + 1;
		var day = currentTime.getDate();
		var year = currentTime.getFullYear();
		var seconds = currentTime.getSeconds();
		if (hours < 10){
			hours = "0"+hours;
		}
		if (minutes < 10){
			minutes = "0"+minutes;
		}
		if (seconds < 10){
			seconds = "0"+seconds;
		}
		if (month < 10){
			month = "0"+month;
		}
		if (day < 10){
			day = "0"+day;
		}
		dojo.byId("generatedtime").innerHTML = "Generated at: "+year+"/"+month+"/"+day+" "+hours+":"+minutes+":"+seconds;
	}
	function reportExcel(){
		window.open(report.store.url+"&exporttype=excel")
	}
	function cleanFilter(id){
		dijit.byId(id).attr('value','');
	}
	var reporttimeoutMS = 600000;
	var reporttimeout = null;
	function updReport(cleartimeout){
		report.store.close();
		//report.store = new dojo.data.ItemFileReadStore({ url: "stores.php?report_type="+currentreport+"&start_date="+dijit.byId('startDate').toString()+"&end_date="+dijit.byId('endDate').toString(),onComplete: calcTotals});
		report.clearSubtotalCache;
		report._setStore(new dojo.data.ItemFileReadStore({ url: "stores.php?report_type="+currentreport+"&keyword="+dojo.byId(currentreport+"keyword").value+"&start_date="+dijit.byId('startDate').toString()+"&end_date="+dijit.byId('endDate').toString()}));
		report.store.fetch({onComplete: calcTotals});
		report._refresh();
		if (cleartimeout == 1){
			clearTimeout(reporttimeout);
		}
		reporttimeout = setTimeout(function(){updReport(0)},reporttimeoutMS);
		setGeneratedTime();
	}
	function newTimeout(value){
		clearTimeout(reporttimeout);
		if (value < 29 && value > 10){
			value = 30;
		}else if(value <= 10){
			return;
		}
		value = Math.round(value);
		var tempo = "Updating Every ";
		var minutes = 0;
		if (value > 60){
			minutes = Math.floor(value / 60);
		}
		var seconds = Math.round(value % 60);
		if (minutes > 0){
			tempo += minutes+" Min";
			if (minutes > 1){
				tempo += "s";
			}
			tempo += " ";
		}
		if (seconds > 0){
			tempo += seconds+" Secs";
		}
		reporttimeoutMS = value*1000;
		reporttimeout = setTimeout(function(){updReport(0)},reporttimeoutMS);
	}
	function returnFloat(value){
		if (isNaN(parseFloat(value))){
			return 0;
		}else{
			return parseFloat(value);
		}
	}
	function formatHHMMSS(value, rowIdx){
		if (!/^\d+$/.test(value)){
			return value;
		}
		value = returnFloat(value);
		var hrs = Math.floor(value / 3600) + "";
		var mins = Math.floor((value / 60) % 60) + "";
		var secs = value % 60 + "";
		while (hrs.length < 2){
			hrs = "0" + hrs;
		}
		while (mins.length < 2){
			mins = "0" + mins;
		}
		while (secs.length < 2){
			secs = "0" + secs;
		}
		return (hrs + ":" + mins + ":" + secs);
	}
	function displayParameters(){
		dojo.query(".reportparam").forEach(function (node, index, arr){
			dojo.style(node,"display","none");
		});
		dojo.style(dojo.byId(dijit.byId("report_type_select").attr('value')+"param"),"display","block");
	}
	function changeReport(){
		loadForm({"report_type" : dijit.byId("report_type_select").attr('value')});
	}
	function loadReport(action){
		report._setStore(new dojo.data.ItemFileReadStore({ url: "stores.php?report_type="+action+"&keyword="+dojo.byId(action+"keyword").value+"&start_date="+dijit.byId('startDate').toString()+"&end_date="+dijit.byId('endDate').toString()}));
		report.store.fetch({onComplete: calcTotals});
		report._refresh();
		currentreport = action;
		reporttimeout = setTimeout(function(){updReport(0)},reporttimeoutMS);
	}
	function loadForm(action){
		dojo.xhrPost({
			url: "reports.php",
			handleAs: "text",
			content: action,
			load: function(data){
				dijit.byId("content").attr('content',data);
				loadReport(action.report_type);
			},
			error:function(data){
				console.debug("An error ocurred :",data);
				dojo.animateProperty({ node: "reportinfo",duration: 2000,properties: {backgroundColor: { start: "#FFFFFF", end: '#FFEEEE'}}}).play();
			},
			timeout: 3000
		});
	}
	dojo.addOnLoad(function(){
//		loadForm({"report_type" : "calldetail"});
//		setGeneratedTime();
		displayParameters();
		dijit.byId("reportWizard").show();
	});
</script>
<link rel="stylesheet" type="text/css" href="../dojo/dijit/themes/tundra/tundra.css"></link>
<link rel="stylesheet" type="text/css" href="../dojo/dojo/resources/dojo.css"></link>
<link rel="stylesheet" type="text/css" href="../dojo/dojox/grid/resources/Grid.css"></link>
<link rel="stylesheet" type="text/css" href="../dojo/dojox/grid/resources/tundraGrid.css"></link>
<link rel="stylesheet" type="text/css" href="../dojo/dojox/dijit/tests/css/dijitTests.css"></link>
<style type="text/css">
html, body { width: 100%; height: 100%; margin: 0; padding: 0;}
.dojoxGrid{
	height : 100%;
}
</style>
</head>
<body class="tundra">
	<div dojoType="dijit.layout.BorderContainer" style="width: 100%; height: 100%">
		<div dojoType="dijit.layout.ContentPane" region="top" style="height:10%">
			<table style="border: 1px dotted black;">
				<tr>
					<td style="width:10%"><strong>Start Date</strong></td>
					<td style="width:10%"><input id="startDate" dojoType="dijit.form.DateTextBox" onChange="updReport(1)" constraints="{datePattern:'yyyy/MM/dd'}" required="false" value="<?echo date("Y-m-d");?>"/></td>
					<td style="width:10%"><strong>End Date</strong></td>
					<td style="width:10%"><input id="endDate" dojoType="dijit.form.DateTextBox" onChange="updReport(1)" constraints="{datePattern:'yyyy/MM/dd'}" required="false" value="<?echo date("Y-m-d");?>"/></td>
					<td style="width:10%">
						<button dojoType="dijit.form.Button" iconClass="noteIcon" type="button" onClick="dijit.byId('reportWizard').show()">Report Wizard</button>
					</td>
					<td style="width:15%">
						<div id="generatedtime">Reading info</div>
					</td>
				</tr>
			</table>
		</div>
		<div dojoType="dijit.layout.ContentPane" region="center" style="height:76%">
			<div id="reportinfo"><strong>Call Information:</strong></div>
			<div id="content" dojoType="dojox.layout.ContentPane" errorMessage="Error loading content" loadingMessage="Loading..." parseOnLoad="true" preventCache="true" refreshOnShow="true" executeScripts="true" style="height:80%"></div>
			<div id="totals" style="width:100%"></div>
		</div>
		<div dojoType="dijit.layout.ContentPane" region="bottom" style="height:8%">
			GreenCore Solutions logo, etc etc
		</div>
	</div>
	<div dojoType="dijit.Dialog" id="reportWizard" title="Report Wizard" execute="changeReport()">
	<table style="width:100%;height:100%">
		<tr>
			<td>Please select a report <strong>type</strong>.</td>
			<td></td>
			<td></td>
		</tr>
		<tr>
			<td>
				<select name="report_type" id="report_type_select" dojoType="dijit.form.Select" onChange="displayParameters()">
					<option value="calldetail">All Calls</option>
					<option value="agentdetail">Agent Detail</option>
					<option value="abandon">Abandon Calls</option>
					<option value="xfer">Transfer Calls</option>
					<option value="inbound">Inbound Calls</option>
					<option value="outbound">Outbound Calls</option>
					<option value="queuestats">Queue Stats</option>
				</select>
			</td>
			<td></td>
			<td></td>
		</tr>
		<tr>
			<td>Report <strong>Options</strong></td>
			<td></td>
			<td></td>
		</tr>
		<tr class="reportparam" id="calldetailparam">
			<td><input dojoType="dijit.form.ValidationTextBox" style="display:none" id="calldetailkeyword"/></td>
			<td>There are no options for this report type</td>
			<td></td>
		</tr>
		<tr class="reportparam" id="outboundparam">
			<td><input dojoType="dijit.form.ValidationTextBox" style="display:none" id="outboundkeyword"/></td>
			<td>There are no options for this report type</td>
			<td></td>
		</tr>
		<tr class="reportparam" id="inboundparam">
			<td><strong>Queue</strong> Called:</td>
			<td><input dojoType="dijit.form.ValidationTextBox" id="inboundkeyword"/></td>
			<td></td>
		</tr>
		<tr class="reportparam" id="agentdetailparam">
			<td>Detail for <strong>Agent</strong>:</td>
			<td><input dojoType="dijit.form.ValidationTextBox" id="agentdetailkeyword"/></td>
			<td></td>
		</tr>
		<tr class="reportparam" id="abandonparam">
			<td>Abandon <strong>Source</strong>:</td>
			<td><input dojoType="dijit.form.ValidationTextBox" id="abandonkeyword"/></td>
			<td></td>
		</tr>
		<tr class="reportparam" id="xferparam">
			<td>Transfer <strong>Agent</strong>:</td>
			<td><input dojoType="dijit.form.ValidationTextBox" id="xferkeyword"/></td>
			<td></td>
		</tr>
		<tr class="reportparam" id="queuestatsparam">
			<td><strong>Queue</strong> Statistics keyword:</td>
			<td><input dojoType="dijit.form.ValidationTextBox" id="queuestatskeyword"/></td>
			<td></td>
		</tr>
		<tr><td></td><td><button dojoType="dijit.form.Button" type="submit">Continue</button></td><td></td></tr>
	</table>
	</div>
</body>
</html>
