//
// 	Code designed and written by Laurens Schuurkamp @ Waag Society 1013 --> suggestions laurens@waag.org
//	The code is not perfect at all, so please feel free to compliment for improvements.
//	I learn from you, you learn from me, we learn......
//

var canvas, info, wrapper, jQueryMenu, accordion, mainContainer, menuContainer, topLine, bottomLine, menuItems;
var updateStage=false;

var sW=32;
var sH=25;
var linecross=10;
var dashSize=1;

var canvasW=410;
var menuW=340;

var layerStack=[];
var visibleSubs;

function initOverlay(){
		
	console.log("canvas initted");
	
	wrapper=document.getElementById("canvasWrapper");
	$("#canvasWrapper").css({
		'position':"absolute",
		'left':0+"px",
	    'top':0+"px"
	});
	
	var canvas = document.createElement('canvas');
	canvas.id     = "menuCanvas";
	canvas.width  = canvasW;
	canvas.height = window.innerHeight;
	wrapper.appendChild(canvas);
	
	$("#menuCanvas").css({
		'position':"absolute",
		'left':0+"px",
	    'top':0+"px",
	    'z-index':10
	});
	
	wrapper.addEventListener( 'mousemove', onCanvasOver, false );
	wrapper.addEventListener('mouseout', onCanvasOut, false);

		
	$("#feedback").css({
		'position':"absolute",
		'height':28+"px",
		'width':window.innerWidth-10+"px",
		'left':10+"px",
		'text-align':"right",
		'top':window.innerHeight-16+"px",
		'font-size': 10+"px",
		'z-index':1000
	});
	
	$("#progressbar").css({
		'z-index':0
	});

	$("#slider").css({
		'position':"absolute",
		'top':10+"px",
		'left':menuW+10+"px",
		'z_index':1500,
		'width':640+'px'
	});
	setCanvas();
	

}


function setCanvas(){

	canvas = document.getElementById("menuCanvas");
	//check to see if we are running in a browser with touch support
	stage = new createjs.Stage(canvas);
	
	// extend line class
	createjs.Graphics.prototype.dashedLineTo = function(x1, y1, x2, y2, dashLen) {
			    this.moveTo(x1, y1);
		
			    var dX = x2 - x1;
			    var dY = y2 - y1;
			    var dashes = Math.floor(Math.sqrt(dX * dX + dY * dY) / dashLen);
			    var dashX = dX / dashes;
			    var dashY = dY / dashes;
		
			    var q = 0;
			    while (q++ < dashes) {
			        x1 += dashX;
			        y1 += dashY;
			        this[q % 2 == 0 ? 'moveTo' : 'lineTo'](x1, y1);
			    }
			    this[q % 2 == 0 ? 'moveTo' : 'lineTo'](x2, y2); 
			}

	// enable touch interactions if supported on the current device:
	//createjs.Touch.enable(stage);
	
	mainContainer = new createjs.Container();
	stage.addChild(mainContainer);
	
	var title=createLabel("OpenData Globe", 32, "#fff", false, "left", "middle");
	title.x=10;
	title.y=32;
	stage.addChild(title);
	stage.update();
	initRepository();
	
}


function initJQueryMenu(dataLayers){
	//wrapper_accordion
	jQueryMenu=document.getElementById("wrapper_jQueryMenu");
	$("#jQueryMenu").css({
		'position':"absolute",
		'left':0+"px",
	    'top':0+"px",
		'z-index':100
		
	});

	accordion=document.getElementById("accordion");
	$("#accordion").css({
		'width':menuW+"px",
			
	});
	

	for(var i=0; i<dataLayers.length; i++){
		var items=creatAccordionItems(i);
	}
	
	var label="Settings";
	var subs=["Toggle 2D-3D projection"];
	var additionalItem=setAdditionalMenuItem(label, subs);
	
	var label="About CitySDK";
	var subs=[]
	var additionalItem=setAdditionalMenuItem(label, subs);
	

	// $(function() {
	// 		    $( "#accordion").accordion({
	// 		      heightStyle: "content",
	// 				active:false,
	// 			  collapsible: true
	// 		
	// 		    });
	// 		  });§
	
	$(function(){
				$('#accordion').multiOpenAccordion({
						heightStyle: "content",
						
						click: function(event, ui) {
							//console.log('clicked')
						},
						init: function(event, ui) {
						//console.log('accorion init")
						},
						tabShown: function(event, ui) {
							//console.log('shown')
						},
						tabHidden: function(event, ui) {
							//console.log('hidden :'+event.target)
							//console.log("active :"+ui.tab);
							var el=ui.tab[0];
							var data=$(el).data();
							if(data.mainIndex!=false){
								for(var i=0; i<dataLayers[data.mainIndex].layers.length; i++){
									dataLayers[data.mainIndex].layers[i].visible=false;
									if(dataLayers[data.mainIndex].layers[i].subs.length>0){
										$(dataLayers[data.mainIndex].layers[i].btnSubs).hide();
									}
									
									
									globe.toggleLayer(dataLayers[data.mainIndex].layers[i]);
								}
								
							}

						}
					});
				$('#accordion').multiOpenAccordion("option", "active", [5]);
			});
			
	$(function() {
	    $( "#progressbar" ).progressbar({
	      value: 0
	    });
	  });
	
	//  $(function() {
	// 
	// 	$( document ).tooltip();
	// 
	// });
	
	$(function() {
	    $( "#slider" ).slider({
			values: [ 17, 67 ]
		});
	  });
	
	initD3();
		

}

function setAdditionalMenuItem(label, subs){
	console.log("adding additional items");
	var header = document.createElement("h3");
	$(header).data({'mainIndex':false})
	var divMain = document.createElement("div");
	$(header).text(label);
	
	
	var ul = document.createElement("ul");
	$(divMain).append(ul);
	
	for(var i=0; i<subs.length; i++){
		var divSub = document.createElement("div");
		$(ul).append(divSub);
		
		li = document.createElement("li");
		$(divSub).append(li);
					
		$(li).text(subs[i]);
		$(li).hover(function(event) {
			$(event.currentTarget).css({
				'cursor':'pointer',
				'color': fontBlue
				});
			}, function(event) {
			$(event.currentTarget).css({
				'cursor':'auto',
				'color': '#cccccc'
			}
			);
		});
		
		$(li).click(function(event) {
			globe.toggleProjection();

		});
		
		
	}
	
	if(label=="About CitySDK"){
		$(divMain).css({
			'font-size':1.0+'em'

		});
		var infoTxt="The dynamics of European cities are made visible in the Open Data Globe, based on available (live) mobility data. The data comes from the CitySDK API, a platform that allows for easy and uniform distribution of European open data. New datasets are (semi) automatically added to the visualization, all data are available for developers and cities can easily make their data available. Do you want to develop an application using Open Data? Check out the developers page <a href=http://dev.citysdk.waag.org>http://dev.citysdk.waag.org</a>. Do you want to know more about the project CitySDK? Visit the project page <a href=http://www.citysdk.eu>http://www.citysdk.eu</a>."
		infoTxt+="<br><br>Open Data (and Big Data) are hot: citizens and (government) agencies create and collect a lot of data: data that may be very valuable for social change and innovation. However, much of this information is not, or only partially available and released data comes in many forms, making it difficult to combine and reuse. The CitySDK API standardizes the data at the European level and makes the information searchable and available on demand. In this way, developers and researchers have easy access to the information."
		
		//			"A webGL visualisation of City Dynamics based on real-time and scheduled Open Data in the European CitySDK Platform.The CitySDK API is an open, interoperable interface which enables easy development and distribution of digital services and data across different cities. The API is a powerful tool that helps governments and officials alike. The developers’ site is currently at <a href=http://dev.citysdk.waag.org>http://dev.citysdk.waag.org</a>. For more information on the CitySDK Project, have a look at the project website <a href=http://www.citysdk.eu>http://www.citysdk.eu</a>.");
		$(divMain).html(infoTxt);
		var img = document.createElement("img");
		// $(img).css({
		// 			'position':"absolute",
		// 			'left':30+"px",
		// 			'top':50+"px"
		// 		});
		img.src = "images/logos/logos_menu.png";
		divMain.appendChild(img);
	
	
	}
	
	
	// var ul = document.createElement("ul");
	// 	$(divMain).append(ul);
	
	$(accordion).append(header);
	$(accordion).append(divMain);
	
	//$( accordion ).accordion({ active: 5 });
	//$( accordion ).accordion( "option", "active", 5 );
	
}

function creatAccordionItems(mainIndex){
	
	var header = document.createElement("h3");
	
	var divMain = document.createElement("div");
	// $(div).css({
	// 		'width':240+"px",
	// 		'background-color': 'rgba(255, 0, 0, 0.5)'
	// 	    
	// 	});
	
	var divSub;
	var ul;
	var li;
	
	$(header).text(dataLayers[mainIndex].label);
	$(header).data({'mainIndex':mainIndex})
	ul = document.createElement("ul");
	$(divMain).append(ul);
	
	for(var i=0; i<dataLayers[mainIndex].layers.length; i++){
		divSub = document.createElement("div");
		$(ul).append(divSub);
		dataLayers[mainIndex].layers[i].visible=false;
		dataLayers[mainIndex].layers[i].loaded=false;
		
		li = document.createElement("li");
		$(divSub).append(li);
			
		$(li).data({'mainIndex':mainIndex, 'layerIndex':i })
		$(li).text(dataLayers[mainIndex].layers[i].label);
		$(li).hover(function(event) {
			$(event.currentTarget).css({
				'cursor':'pointer',
				'color': fontBlue
				});
			}, function(event) {
			$(event.currentTarget).css({
				'cursor':'auto',
				'color': '#cccccc'
			}
			);
		});
		

		if(dataLayers[mainIndex].layers[i].subs.length>0){
			var liSub, ulSubs;
			ulSub=document.createElement("ul");

			$(ulSub).hide();
					
			$(ulSub).css({
				'margin-top': -16+"px",
				'margin-left': 100+"px",
				'visible':false
			    
			});
			$(ul).append(ulSub);
			dataLayers[mainIndex].layers[i].btnSubs=ulSub;
			//var data= $(li).data();
			//data.layer.btnSubs=ulSub;
			
			for(var j=0; j<dataLayers[mainIndex].layers[i].subs.length; j++){
				liSub=document.createElement("li");
				var fontcolor=fontBlue;
				if(dataLayers[mainIndex].layers[i].subs[j]=="bus"){
					fontcolor="#da0000"
				}else if(dataLayers[mainIndex].layers[i].subs[j]=="tram"){
					fontcolor="#d300d1"
				}else if(dataLayers[mainIndex].layers[i].subs[j]=="ferry"){
					fontcolor="#00dfed"
				}else if(dataLayers[mainIndex].layers[i].subs[j]=="subway"){
					fontcolor="#06ed00"
				}
				
				$(liSub).css({
					'color': fontcolor
					});
				$(liSub).text(dataLayers[mainIndex].layers[i].subs[j]);
				$(liSub).attr({
					'mainIndex':mainIndex,
					'layerIndex':i,
					'layer':dataLayers[mainIndex].layers[i].layer,
					'layerSub':dataLayers[mainIndex].layers[i].subs[j],
					'subIndex': j,
					'active':true,
					'color':fontcolor
					});
				$(liSub).hover(function(event) {
					$(event.currentTarget).css({
						'cursor':'pointer'
						});
					}, function(event) {
					$(event.currentTarget).css({
						'cursor':'auto'
					}
					);
				});
				
				$(liSub).click(function(event) {

					if($(event.currentTarget).attr('active')=='false'){
						
						globe.toggleSubLayer($(event.currentTarget).attr('layer'), $(event.currentTarget).attr('layerSub'), true);
						$(event.currentTarget).attr({
							active: true
						});
						var color=$(event.currentTarget).attr('color');
						
						$(event.currentTarget).css({
							'color': color
						});
					}else{
						
						globe.toggleSubLayer($(event.currentTarget).attr('layer'), $(event.currentTarget).attr('layerSub'), false);
						$(event.currentTarget).attr({
							active: false
						});
						
						$(event.currentTarget).css({
							'color': '#cccccc'
						});

					}
	

				});
				
				console.log("adding subs");
				$(ulSub).append(liSub);
			}
			
		}

		$(li).click(function(event) {
			//console.log( $( event.currentTarget ).get(  ) );
			
			var data= $(event.currentTarget).data();
			//console.log("mainIndex ="+data.mainIndex+" layer ="+data.layerIndex);
			
			if(dataLayers[data.mainIndex].layers[data.layerIndex].visible==false){
				
				$(event.currentTarget).off('mouseenter mouseleave');
				getApiData(dataLayers[data.mainIndex].layers[data.layerIndex]);
				globe.focusCity(dataLayers[data.mainIndex].layers[data.layerIndex].ll);
				dataLayers[data.mainIndex].layers[data.layerIndex].visible=true;
				
				if(!dataLayers[data.mainIndex].layers[data.layerIndex].loaded){	
					dataLayers[data.mainIndex].layers[data.layerIndex].layer.loaded=true;	
				}
				if(visibleSubs){
					$(visibleSubs).hide();
	
				}
				for(var s=0; s<dataLayers[data.mainIndex].layers.length; s++){
					if(dataLayers[mainIndex].layers[s].subs.length>0){
						$(dataLayers[mainIndex].layers[s].btnSubs).hide();
					}
					
				};
				
				
				visibleSubs=dataLayers[data.mainIndex].layers[data.layerIndex].layer.btnSubs;
				
				$(dataLayers[data.mainIndex].layers[data.layerIndex].btnSubs).show();

	
			}else{

				dataLayers[data.mainIndex].layers[data.layerIndex].visible=false;
				$(dataLayers[data.mainIndex].layers[data.layerIndex].btnSubs).hide();
				
				
				$(event.currentTarget).hover(function(event) {
					$(event.currentTarget).css({
						'cursor':'pointer',
						'color': fontBlue
						});
					}, function(event) {
					$(event.currentTarget).css({
						'cursor':'auto',
						'color': '#cccccc'
					}
					);
				});
								
			}
			
			globe.toggleLayer(dataLayers[data.mainIndex].layers[data.layerIndex]);


		});
	
	}
		
	$(accordion).append(header);
	$(accordion).append(divMain);
		
	return true;
	
}

function toggleMenuLayers(){
	
}





function createLabel(txt, size, color, outline, align, baseline){
	
	var label = new createjs.Text(txt, size+"px Futura, sans-serif", color);
	label.textAlign = align;
	label.textBaseline = baseline; // draw text relative to the top of the em box.
	label.outline=outline;
	return label;
	
	
}

var infoActive=false;


function tweenInfo(py){
	
	$("#info").css({
		'position':"absolute",
		'height':240+"px",
		'width': 640,
		'left':(window.innerWidth/2)-320+"px",
		'top':py+"px",
		'z-index':100
	});
	
}

var menuActive=true;

function toggleMainMenu(active){
	
	if(menuActive && active)return;
	if(!menuActive && !active)return;
	clearInterval(timerMenu);
	var o, t;
 	if(menuActive==false){
	//console.log(parseInt(wrapper.style.left));
		o = { x : parseInt(wrapper.style.left), y: 0 };
		t = { x : 0, y: 0 };
		menuActive=true;
		//console.log("open menu");
	}else{
		o = { x : parseInt(wrapper.style.left), y: 0 };
		t = { x : -menuW, y: 0 };
		menuActive=false;
	}
	
	
	new TWEEN.Tween( o ).to( {
		x: t.x, 
		}, 750 )
		.easing( TWEEN.Easing.Quartic.EaseOut )
		.start()
		.onUpdate(function(){ 
			wrapper.style.left=o.x+"px"; 
			stage.update();
		})
		.onComplete(function(){
			
		});
	
}

function onCanvasDown(event){
	toggleMainMenu(true);
	clearInterval(timerMenu);

}

function onCanvasOver(event){
	clearInterval(timerMenu);
	tooltip.hide();
	toggleMainMenu(true);
	

}
var timerMenu;
function onCanvasOut(event){
	//timerMenu=setInterval(function(){toggleMainMenu(false)}, 5000);

}

function onComplete(){	
	stage.update();
	//update=false;
}

