//
// 	Code designed and written by Laurens Schuurkamp @ Waag Society 1013 --> suggestions laurens@waag.org
//	The code is not perfect at all, so please feel free to compliment for improvements.
//	I learn from you, you learn from me, we learn......
//


var apiUrl="http://api.citysdk.waag.org/";

var ptSchedules=[];

var schedulesInited=false;
var maxEntrys=1000;

var llReset={city:"reset", admr:"admr.nl.nederland", lat:0, lng:0, d:9000};
var llAmsterdam={city:"amsterdam", admr:"admr.nl.amsterdam", lat:52.3734, lng:4.8921, d:20};
var llNl={city:"netherlands", admr:"admr.nl.nederland", lat:52.3734, lng:4.8921, d:275};
var llManchester={city:"manchester", admr:"admr.uk.gr.manchester", lat:53.4800, lng:-2.15, d:30}; // manchester 
var llIstanbul={city:"istanbul", admr:"admr.tr.istanbul", lat:41.0128, lng:28.9744, d:50}; // istanbul
//var llRome={city:"rome", admr:"admr.nl.nederland", lat:41.9000, lng:12.5000, d:6250}; // rome
var llHelsinki={city:"helsinki", admr:"admr.fi.helsinki", lat:60.2311, lng:24.9898, d:20}; // helsinki 60.23117077837895, 24.989808077582467
var llTampere={city:"tampere", admr:"admr.fi.tampere", lat:61.4943, lng:23.7966, d:20}; // Tampere
var llEindhoven={city:"eindhoven", admr:"admr.nl.eindhoven", lat:51.444018, lng:5.488247, d:20}; // 
var llRotterdam={city:"rotterdam", admr:"admr.nl.rotterdam", lat:51.925214, lng:4.463661, d:20}; //
var llUtrecht={city:"utrecht", admr:"admr.nl.utrecht", lat:52.09451, lng:5.120868, d:20};
var llDenHaag={city:"sgravenhage", admr:"admr.nl.sgravenhage", lat:52.08481, lng:4.32024, d:20};
// 
var llDroneAttacks={city:"None", admr:"admr.afg.droneattacks", lat:33.54109, lng:70.210922 , d:1000}; //}


//var sdkData={layer:"some_layer", results:["0", "1", ......]}

var dataLayers=[];

function initRepository(){
	console.log("init repository")
	
	
	dataLayer={
		label:"Live public transport",
		layers:[
			{label:"Amsterdam", subs:["tram", "bus", "subway", "ferry"], ll:llAmsterdam, apiCall:llAmsterdam.admr+"/ptlines?geom", regions:false, layer:"amsterdam_pt_live", properties:{static:false, dotSize:0.25, lines:true, shape:false, stacked:false}},
			{label:"Utrecht", subs:["tram", "bus", "subway", "ferry"], ll:llUtrecht, apiCall:llUtrecht.admr+"/ptlines?geom", regions:false, layer:"utrecht_pt_live", properties:{static:false, dotSize:0.25, lines:true, shape:false, stacked:false}},
			{label:"Den Haag", subs:["tram", "bus", "subway", "ferry"], ll:llDenHaag, apiCall:llDenHaag.admr+"/ptlines?geom", regions:false, layer:"sgravenhage_pt_live", properties:{static:false, dotSize:0.25, lines:true, shape:false, stacked:false}},
			{label:"Rotterdam", subs:["tram", "bus", "subway", "ferry"], ll:llRotterdam, apiCall:llRotterdam.admr+"/ptlines?geom", regions:false, layer:"rotterdam_pt_live", properties:{static:false, dotSize:0.25, lines:true, shape:false, stacked:false}},
			//{label:"Eindhoven", subs:["tram", "bus", "subway", "ferry"], ll:llEindhoven, apiCall:llRotterdam.admr+"/ptlines?geom", regions:false, layer:"eindhoven_pt_live", properties:{static:false, dotSize:0.25, lines:true, shape:false, stacked:false}},
			{label:"Tampere", subs:["tram", "bus", "subway", "ferry"], ll:llTampere, apiCall:llTampere.admr+"/ptlines?geom", regions:false, layer:"tampere_pt_live", properties:{static:false, dotSize:0.25, lines:true, shape:false, stacked:false}},
			{label:"Helsinki", subs:["tram", "bus", "subway", "ferry"], ll:llHelsinki, apiCall:llHelsinki.admr+"/ptlines?geom", regions:false, layer:"helsinki_pt_live", properties:{static:false, dotSize:0.25, lines:true, shape:false, stacked:false}},
			//{label:"Manchester", subs:["tram", "bus", "subway", "ferry"], ll:llManchester, apiCall:llManchester.admr+"/ptlines?geom", regions:false, layer:"manchester_pt_live", properties:{static:false, dotSize:0.1, lines:true, shape:false, stacked:false}},
			 {label:"Istanbul", subs:["tram", "bus", "subway", "ferry"], ll:llIstanbul, apiCall:llIstanbul.admr+"/ptlines?geom", regions:false, layer:"istanbul_pt_live", properties:{static:false, dotSize:0.25, lines:true, shape:false, stacked:false}}
			]
		 
	};
	dataLayers.push(dataLayer);
	
	//traffic flows
	var dataLayer;
		dataLayer={
		label:"Realtime traffic flow",
		layers:[
			{label:"Amsterdam", subs:[], ll:llAmsterdam, apiCall:"nodes?layer=divv.traffic&geom", regions:false, layer:"trafic_flow_adam", properties:{static:false, dotSize:0.5, lines:true, shape:false, stacked:false}} 
		]
		 
	};

	dataLayers.push(dataLayer);
	
	// pt stops
	// dataLayer={
	// 		label:"public transport schedules",
	// 		layers:[
	// 			{label:"Amsterdam", ll:llAmsterdam, apiCall:"admr.nl.amsterdam/ptstops?geom&layer=gtfs", regions:false, layer:"amsterdam_ptstops", dynamic:true, lines:true, loaded:false},
	// 			{label:"Manchester", ll:llManchester, apiCall:"admr.uk.gr.manchester/ptstops?geom&layer=gtfs", regions:false, layer:"manchester_ptstops", dynamic:false, lines:true, loaded:false}, 
	// 			{label:"Helsinki", ll:llHelsinki, apiCall:"admr.fi.helsinki/ptstops?geom&layer=gtfs", regions:false, layer:"helsinki_ptstops", dynamic:false, lines:true, loaded:false},
	// 			{label:"Tampere (fi)", ll:llTampere, apiCall:"admr.fi.tampere/ptstops?geom&layer=gtfs", regions:false, layer:"tampere_ptstops", dynamic:false, lines:true, loaded:false},
	// 			{label:"Istanbul", ll:llIstanbul, apiCall:"admr.tr.istanbul/ptstops?geom&layer=gtfs", regions:false, layer:"istanbul_ptstops", dynamic:false, lines:true, loaded:false},
	// 			{label:"Netherlands (all)", ll:llNl, apiCall:"admr.nl.nederland/regions?admr::admn_level=3", regions:true, layer:"nl_ptstops", dynamic:false, lines:true, loaded:false}
	// 
	// 			]
	// 		 
	// 	};

	//ptlines
		dataLayer={
		label:"Public transport (static)",
		layers:[
			{label:"Amsterdam", subs:['lines', 'stops'], ll:llAmsterdam, apiCall:llAmsterdam.admr+"/ptlines?geom", regions:false, layer:"amsterdam_ptlines", properties:{static:true, dotSize:0.25, lines:true, shape:false, stacked:false}},
			{label:"Rotterdam", subs:['lines', 'stops'], ll:llRotterdam, apiCall:llRotterdam.admr+"/ptlines?geom", regions:false, layer:"rotterdam_ptlines", properties:{static:true, dotSize:0.25, lines:true, shape:false, stacked:false}},
			//{label:"Eindhoven", subs:['lines', 'stops'], ll:llEindhoven, apiCall:llEindhoven.admr+"/ptlines?geom", regions:false, layer:"eindhoven_ptlines", properties:{static:true, dotSize:0.25, lines:true, shape:false, stacked:false}},
			{label:"Manchester", subs:[], ll:llManchester, apiCall:llManchester.admr+"/ptlines?geom", regions:false, layer:"manchester_ptlines", properties:{static:true, dotSize:0.25, lines:false, shape:false, stacked:false}},
			{label:"Helsinki", subs:['lines', 'stops'], ll:llHelsinki, apiCall:llHelsinki.admr+"/ptlines?geom", regions:false, layer:"helsinki_ptlines", properties:{static:true, dotSize:0.25, lines:true, shape:false, stacked:false}},
			{label:"Tampere", subs:['lines', 'stops'], ll:llTampere, apiCall:llTampere.admr+"/ptlines?geom", regions:false, layer:"tampere_ptlines", properties:{static:true, dotSize:0.25, lines:true, shape:false, stacked:false}},
			{label:"Istanbul", subs:['lines', 'stops'], ll:llIstanbul, apiCall:llIstanbul.admr+"/ptlines?geom", regions:false, layer:"istanbul_ptlines", properties:{static:true, dotSize:0.25, lines:true, shape:false, stacked:false}},
			{label:"Netherlands (all stops)", subs:[], ll:llNl, apiCall:llNl.admr+"/regions?admr::admn_level=3", regions:true, layer:"nl_ptstops", properties:{static:true, dotSize:0.25, lines:false, shape:false, stacked:true}}
			//,{label:"Netherlands railways", subs:[], ll:llNl, apiCall:"nodes?layer=ns&geom", regions:false, layer:"nl_ns", geometry:{dynamic:false, dotSize:0.5, lines:false, shape:false}}
			
			]
		 
	};
	dataLayers.push(dataLayer);
		
	dataLayer={
			label:"Census data",
			layers:[
				// {label:"Amsterdam", subs:[], ll:llAmsterdam, apiCall:llAmsterdam.admr+"/regions?admr::admn_level=4&layer=cbs&geom", regions:false, layer:"cbs_amsterdam", geometry:{dynamic:false, dotSize:0, lines:false, shape:true, stacked:false}},
				// 				{label:"Rotterdam", subs:[], ll:llRotterdam, apiCall:llRotterdam.admr+"/regions?admr::admn_level=4&layer=cbs&geom", regions:false, layer:"cbs_rotterdam", geometry:{dynamic:false, dotSize:0, lines:false, shape:true, stacked:false}},
				// 				{label:"Eindhoven", subs:[], ll:llEindhoven, apiCall:llEindhoven.admr+"/regions?admr::admn_level=4&layer=cbs&geom", regions:false, layer:"cbs_eindhoven", geometry:{dynamic:false, dotSize:0, lines:false, shape:true, stacked:false}},
				{label:"Netherlands", subs:[], ll:llNl, apiCall:llNl.admr+"/regions?admr::admn_level=3", regions:true, layer:"cbs_nl", properties:{static:true, dotSize:0, lines:false, shape:true, stacked:true}}
			]
		};
		
		dataLayers.push(dataLayer);
		
	// dataLayer={
	// 				label:"Misc (external api's)",
	// 				layers:[
	// 					{label:"U.S. Drone attacks", subs:[], ll:llDroneAttacks, apiCall:"http://api.dronestre.am/data", regions:false, layer:"drone_attacks", properties:{static:true, dotSize:50, lines:false, shape:false, stacked:false}}
	// 				]
	// 				
	// 			};
	// 			dataLayers.push(dataLayer);	

	initJQueryMenu(dataLayers);
	
	
}
var recJsonData=[];
function loadRecordedData(){
	
	if(recJsonData.length>0){
		frameCount=0;
	}

	$.get("data/recorded_data/divv_29042013/recorded_data-all.txt", function(data) {
	  var d=data.split("\n");
	  
      recJsonData=d;

	
		var text = new guiText();
		var gui = new dat.GUI();
		
		var controller = gui.add(text, 'timeline', 0, recJsonData.length);

		controller.onChange(function(value) {
			animateRecorderData(parseInt(value));
			//console.log("value :" + value)
		  
		});

		controller.onFinishChange(function(value) {
		  
		  
		});
      
		//var timerPlayRecordedData=setInterval(function(){animateRecorderData()}, 100);
		animateRecorderData(0);
	});

}

var guiText = function() {
  this.timeline = 0;

};



var divvData;
var timeRec=new Date();
var frameCount=0;
var recSet=0;
function animateRecorderData(frame){
	
	if(frameCount==recJsonData.length-1)return;
		
	var data = $.parseJSON(recJsonData[frame]);
	
	for(var i=0; i<data.results.length; i++){
		if(data.results[i]==null){
			console.log("null ="+i);
			
		}
			
		data.results[i].geom=divvData[i].geom;
		
	}
	timeRec.setTime(data.record_time);
	$("#feedback").html("time = : "+timeRec); 
	globe.addData(data.results, true, "trafic_flow_adam_recorded", 2, false, true);
	//console.log("time ="+timeRec);
	//frameCount++; 	
	
	
}


function getApiData(dataLayer){

	d3.select("svg").remove();
	
	for(var i in dataLayer.geoRepository){
		console.log("adding loaded memory data");
		globe.addLoadedData(dataLayer);		
		return;

	}
		
	if(dataLayer.layer=="drone_attacks"){
		console.log("getting external api data");
		getExternalApiData(dataLayer);
		return;
		
	} 
	dataLayer.geoRepository={};
	dataLayer.loadedSubs=0;
	console.log("getting api data :"+dataLayer.layer);
	
	if(dataLayer.regions){
		getRegions(apiUrl+dataLayer.apiCall+"&per_page="+maxEntrys+"&page=1", 1, dataLayer, null);
	}else{
		//getData(apiUrl+dataLayer.apiCall+"&geom&per_page="+maxEntrys+"&page=1", 1, dataLayer.layer, dataLayer.ll, null, dataLayer.dynamic, dataLayer.dotSize, dataLayer.lines);
		addloadDataQueue(apiUrl+dataLayer.apiCall+"&per_page="+maxEntrys+"&page=1", 1, dataLayer, null);
	}

}



function getRegions(uri, page, dataLayer, resultsArray){
	
	
	d3.json(uri, function(data){
				if(dataLayer.properties.stacked){
					dataLayer.properties.stackAmount=data.results.length;
					dataLayer.properties.stackIndex=0;
					
				}
				var layerOrg=dataLayer.layer;
				
				for(var i=0; i<data.results.length; i++){
					var name=data.results[i].name.toLowerCase();
					var id=data.results[i].cdk_id.toLowerCase();
					var url;
					if(layerOrg=="nl_ptstops"){
						dataLayer.layer="nl_ptstops";
						url=apiUrl+id+"/ptstops?geom&layer=gtfs&per_page="+maxEntrys+"&page=1";
					}else if(layerOrg=="cbs_nl"){
						dataLayer.layer="cbs_nl";
						url=apiUrl+id+"/regions?admr::admn_level=3&layer=cbs&geom&per_page="+maxEntrys+"&page=1";

					}

					var loadObject={
						uri:url,
						page:1,
						resultsArray:null,
						dataLayer:dataLayer
						
					}
					load_queue.push(loadObject);

					$("#feedback").text("api call : "+url);
					loadDataQueue();	
				}
				
			

		});

}


var load_queue=[];
function loadDataQueue(){
	while(load_queue.length)
	{
		var loadObject = load_queue[0]; 
		load_queue.shift();
		getData(loadObject.uri, 1, loadObject.dataLayer, null);
		
	}

}

function addloadDataQueue(uri, page, dataLayer, resultsArray){
	var loadObject={
		uri:uri,
		page:1,
		dataLayer:dataLayer,
		resultsArray:resultsArray
		
	}
	
	if(load_queue.length>0){
		load_queue.unshift(loadObject);
	}else{
		load_queue.push(loadObject);
		loadDataQueue();
	}
	
	
}


function getData(uri, page, dataLayer, resultsArray){
  //console.log("api cal "+uri);	
  $("#feedback").text("api call : "+uri); 	
  d3.json(uri, function(data){
	
			if(data.results.length==0){
				//return;
			}

			if(resultsArray==null)resultsArray=[];		
			
			if(data.results.length<maxEntrys){

				resultsArray=resultsArray.concat(data.results);
				//get time tables
				if(dataLayer.layer==dataLayer.ll.city+"_pt_live"){
					schedulesInited=false;
					getPtLinesData(dataLayer.ll.admr+"/ptlines?geom", dataLayer.layer);
					return;

				}
	

			}else{
				resultsArray=resultsArray.concat(data.results);
				var oldUrl=data.url;
				var n=oldUrl.search("&page=");
				var slicedUrl=oldUrl.slice(0,n);
				var nextPage=page+1;
				var newUrl=slicedUrl+"&page="+nextPage;
				$("#feedback").text("api call : "+newUrl); 	
				
				//var drawProperties={resultsArray:resultsArray, layer:layer, geometry:geometry};
				//draw_queue.push(drawProperties);
							
				getData(newUrl, nextPage, dataLayer, resultsArray);
	
			}
			
			globe.addData(resultsArray, dataLayer);
			
			

	});

}

function getExternalApiData(dataLayer){
	//local call
	// d3.json("data/data_drones.json", function(error, data) {
	// 		globe.addExternalApiData(data, dataLayer);
	// 		setD3GraphDronesBrushed(data);
	// 	});
		
	$.ajax({
		    url: dataLayer.apiCall,
	        dataType: 'jsonp',
	        jsonp: 'callback',
	        success: function(data){
				globe.addExternalApiData(data, dataLayer);
				setD3GraphDronesBrushed(data);
	            console.log("cross domain success");
	        }
	    });
	
}

function getPtLinesData(restUrl, layer){
	if(schedulesInited)return;
	tripsLoaded=0;
	tripsToload=0;
	totalDayTrips=0;

	$("#feedback").text("get : "+apiUrl+restUrl);
	$.getJSON(apiUrl+restUrl+"&per_page="+maxEntrys+"&page=1", function(data) {
				var ptLine={layer:layer, lines:data.results, ptstops:[], scale:{bus:1, tram:1, ferry:1, subway:1}};
				ptSchedules.push(ptLine);

				for(var i=0; i<ptLine.lines.length; i++){
					for(var j=0; j<ptLine.lines[i].geom.coordinates.length; j++){
						var p=ptLine.lines[i].geom.coordinates[j];
						//globe
						var pos=getWorldPosition(p[1], p[0], worldRadius, "GLOBE");
						ptLine.lines[i].geom.coordinates[j].GLOBE=pos;
						
						//mercator
						var pos=getWorldPosition(p[1], p[0], 0, "MERCATOR");
						ptLine.lines[i].geom.coordinates[j].MERCATOR=pos;
						
					}
					
					ptLine.lines[i].schedules=null;
					var line=ptLine.lines[i].cdk_id.slice(0,13);

					//if(line=="gtfs.line.gvb"){				
						var cdk_id=ptLine.lines[i].cdk_id;
						var uri=apiUrl+cdk_id+"/select/schedule";
						getSchedules(uri, i, layer, ptSchedules.length-1);
						
						var uri=apiUrl+cdk_id+"/select/nodes?per_page=100";
						getNodeInfo(uri, i, layer, ptSchedules.length-1);
						
						tripsToload++;
					//}
									
				}

	});
	
}

function updateSchedules(){
	
	// for(var i=0; i<ptLine.lines.length; i++){
	// 			var cdk_id=ptLine.lines[i].cdk_id;
	// 			var uri=apiUrl+cdk_id+"/select/schedule";
	// 			getSchedules(uri, i, layer, ptSchedules.length-1);
	// 			
	// 		
	// 	}
	
}

var tripsLoaded=0;
var tripsToload=0;
var totalDayTrips=0;

function getNodeInfo(uri, index, layer, mainIndex){
	// /console.log(layer);	

	$.getJSON(uri, function(data) {
		//console.log("loaded ptstops :"+uri);
		ptSchedules[mainIndex].lines[index].ptstops=data.results;
	
	});

}


function getSchedules(uri, index, layer, mainIndex){
	// /console.log(layer);	

	$.getJSON(uri, function(data) {
		var tRemember=0;
		for (var i=0; i<data.results[0].trips.length; i++){
			
			for (var j=0; j<data.results[0].trips[i].length; j++){
				var tt=parseTime(data.results[0].trips[i][j][1]);
				data.results[0].trips[i][j][1]=tt.ts;
				var delay=false;
				if(tt.rt!=null){
					delay=tt.ts-tt.rt;
					
				}
				data.results[0].trips[i][j].push(delay);
				
			} 
		}

		ptSchedules[mainIndex].lines[index].indexRemember=0;
		ptSchedules[mainIndex].lines[index].schedules=data.results[0];
		
		//console.log("schedule ="+gvbPtLines.results[index].cdk_id+" --> line ="+gvbPtLines.results[index].schedules.line+" trips :"+gvbPtLines.results[index].schedules.trips.length);
		totalDayTrips+=ptSchedules[mainIndex].lines[index].schedules.trips.length;
		
		var txt="loading line data :"+tripsLoaded+" of "+tripsToload+" public transport lines --> ";
		txt+=ptSchedules[mainIndex].lines[index].schedules.line+" trips :"+ptSchedules[mainIndex].lines[index].schedules.trips.length;
		$("#feedback").html(txt);
		
		schedulesInited=true;
		tripsLoaded++;
		var perc=parseInt( (tripsLoaded/tripsToload)*100 );
		$( "#progressbar" ).progressbar({
	      value: perc
	    });
		
		if(tripsLoaded==tripsToload){
			$("#feedback").text("All live schedules loaded");
			schedulesInited=true;
			$( "#progressbar" ).progressbar({
		      value: 0
		    });
			//console.log("all schedules loaded");
		}
	});

}







