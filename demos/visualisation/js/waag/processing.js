//
// 	Code designed and written by Laurens Schuurkamp @ Waag Society 1013 --> suggestions laurens@waag.org
//	The code is not perfect at all, so please feel free to compliment for improvements.
//	I learn from you, you learn from me, we learn......
//

function getLatLong(pos, r, pMethod){

	var lat, lng;
	if(pMethod=="GLOBE"){

		var phi = Math.acos(pos.y/r);
		lat = 90-phi/(Math.PI / 180);
	
		var theta = Math.acos( pos.x / (r * Math.sin(phi) ) );
		//var theta = Math.asin( position.z /(r * Math.sin(phi) ) );
		lng =180-( theta / (Math.PI / 180));
	
		if(pos.z<0){ 			
				lng= - lng;
				//console.log("lng rehab "+lng)
		}
	}else if(pMethod=="MERCATOR"){
	
		lng=(pos.x/mapHeight)*180;
		lat=(pos.y/mapHeight)*180;
		lat=180/Math.PI*(2*Math.atan(Math.exp(lat*Math.PI/180))-Math.PI/2);

	    //z =  pos.z;
		
	}
		
	var currentLatLong={lat:lat, lng:lng};
	return currentLatLong;

}

function getDistance(pos, pMethod){

	var dist
	if(pMethod=="GLOBE"){
		dist = Math.sqrt((pos.x*pos.x)+(pos.y*pos.y)+(pos.z*pos.z));
	}else if(pMethod=="MERCATOR"){
		dist=pos.z;
	}
	//console.log(dist);
	return dist;
	
}

function getLength(point1, point2, pMethod){
		
	var l = point1.distanceTo( point2 );
	
	//console.log("distance ="+l);
	return l;
}
var halfPi=Math.PI / 180;
var mapHeight   = 6000;

function getWorldPosition(lat, lng, r, pMethod){
	
	  var phi = (90 - lat) * (halfPi);
	  var theta = (180 - lng) * (halfPi);
	  var sinp = Math.sin(phi);
	  var x, y, z;	
	
	if(pMethod=="GLOBE"){
		x = r * sinp * Math.cos(theta);
		y = r * Math.cos(phi);
		z = r * sinp * Math.sin(theta);
		
	}else if(pMethod=="MERCATOR"){

		//x = -(mapWidth/2) + ((mapWidth/360) * (180 + lng));
		//y = (mapHeight/2) - ((mapHeight/180) * (90 - lat));
		
		x= lng*mapHeight/180;
		y= Math.log(Math.tan( (90+lat)*Math.PI/360) )/(Math.PI/180);
		y= y*mapHeight/180;
		z = r;

	}	
	
	

	  
	//console.log("lat org ="+lng+" latRevers ="+lngR);		
	  var pos=new THREE.Vector3();
	  pos.x = x;
	  pos.y = y;
	  pos.z = z;
	  //console.log("pos z:"+pos.z);
	  return pos;
	  
}

function parseTime(time){
	
	var n=0;
	var dateS=new Date();
	var ts; // time schedule
	var rt=null; // realtime time
	
	var entrys=1;
	
	if(time.length>8){
		entrys=2;
	}
	
	for(var i=0; i<entrys; i++){
		if(i==1) {n=10;};
		var h=time.slice(n+0,n+2);
		
		if(h=="24"){
			h="00";
		}else if(h=="25"){
			h="01";
		}else if(h=="26"){
			h="02";
		}else if(h=="27"){
			h="03";
		}else if(h=="28"){
			h="04";
		}else if(h=="29"){
			h="05";
		}else if(h=="30"){
			h="06";
		}

		dateS.setHours(h);
		dateS.setMinutes(time.slice(n+3,n+5));
		dateS.setSeconds(time.slice(n+6,n+8));
		if(i==0){
			ts=dateS.getTime();
		}else if(i==1){
			rt=dateS.getTime();
			var delay=parseInt(rt-ts);
		}
		
		
	}
	
	var t={ts:ts, rt:rt};
	return t;
	
}

//createVector3(pos, ll, dotSize, 0xffffff);
function createVector3(pos, ll, dotSize, color){
	
	var vec3=pos;
	vec3.ll=ll;
	vec3.color=color;
	vec3.pointSize=dotSize;
	return vec3;
	
}


function getSeconds(h, m, s){
	
	var hs=h*3600;
	var ms=m*60;
	var ss=s;

	var seconds=hs+ms+ss;
	return seconds;
	
}

function formatDate(date, milliseconds){
	
	var h, m, s;
	
	if(date!=null){
		h=date.getHours();
		m=date.getMinutes();
		s=date.getSeconds();
		
	}else{
		//h=parsInt(seconds/3600);

	}

	var hs = ( h < 10 ? "0" : "" ) + h;
	var ms = ( m < 10 ? "0" : "" ) + m;
	var ds = ( s < 10 ? "0" : "" ) + s;
	
	var dateString=hs+":"+ms+":"+ds;
	
	return dateString;
	
}

//getColorWidth(d.layers.divv.data.traveltime, d.layers.divv.data.traveltime_ff, d.layers.divv.data.velocity, dataLayer.properties.dotSize, dataLayer.layer)
function getColorWidth(valueRealtime, value, dotSize, layer ){
	var w, c;
	
	var cw;
	w=dotSize;
	var c=0xffffff;

	w=( (valueRealtime/value) * dotSize );
	if(w==-Infinity || w==Infinity ){
		w=dotSize;
	}
	if(w>2.5){
		w=3;
	}
	if(w<0.1){
		w=0.1;
	}
	
	//console.log(w);
	//pct=traveltime_ff/traveltime;
	//c = getColorPercent(pct);
	//w=dotSize;
	cw={c:c, w:w}
	return cw;
}

var percentColors = [
    { pct: 0.0, color: { r: 0xff, g: 0x00, b: 0 } },
    { pct: 0.5, color: { r: 0xff, g: 0xff, b: 0 } },
    { pct: 1.0, color: { r: 0x00, g: 0xff, b: 0 } } ];

function getColorPercent (pct) {
    for (var i = 0; i < percentColors.length; i++) {
        if (pct <= percentColors[i].pct) {
			var lower = (i === 0) ?  percentColors[i] : percentColors[i - 1];
			var upper = (i === 0) ? percentColors[i + 1] : percentColors[i];
            var range = upper.pct - lower.pct;
            var rangePct = (pct - lower.pct) / range;
            var pctLower = 1 - rangePct;
            var pctUpper = rangePct;
            var color = {
                r: Math.floor(lower.color.r * pctLower + upper.color.r * pctUpper),
                g: Math.floor(lower.color.g * pctLower + upper.color.g * pctUpper),
                b: Math.floor(lower.color.b * pctLower + upper.color.b * pctUpper)
            };

			//console.log( "0x" + ((1 << 24) + (color.r << 16) + (color.g << 8) + color.b).toString(16).slice(1,7));
			return "0x" + ((1 << 24) + (color.r << 16) + (color.g << 8) + color.b).toString(16).slice(1,7);
			//console.log('rgb(' + [color.r, color.g, color.b].join(',') + ')');
            //return 'rgb(' + [color.r, color.g, color.b].join(',') + ')';
            // or output as hex if preferred
        }
    }
}


function get_random_color() {
  function c() {
    return Math.floor(Math.random()*256).toString(16)
  }
  return "0x"+c()+c()+c();
}

function recordData(){
	console.log("record");	
	  var uri="http://api.citysdk.waag.org/nodes?layer=divv.traffic&per_page=1000";	
	d3.json(uri, function(data){
		var dateNow=new Date();
		data.record_time=dateNow.getTime();
		
		console.log("adding data");	
		$.post("php/save_data.php", {json : JSON.stringify(data)});
	});
	
}

function sortOnTime(a, b) {

	 if (a[1] < b[1])
	     return -1;
	  if (a[1] > b[1])
	    return 1;
	  return 0;
	}

function countObjects(object){
	var count=0;
	for (var key in object) {
	if (object.hasOwnProperty(key)) {
	      count++;
	    }
	}
	return count;
}


function setForAll(obj, name, value) {
	for(key in obj)
	{
		layer = obj[key];
		layer[name] = value;
		
	}
	
}	

//setForAll(poolPtLive,"visible",false)


