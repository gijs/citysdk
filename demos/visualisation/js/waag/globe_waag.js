//
// 	Code designed and written by Laurens Schuurkamp @ Waag Society 1013 --> suggestions laurens@waag.org
//	The code is not perfect at all, so please feel free to mail me for improvements.
//	I learn from you, you learn from me, we learn......
//

var touchDevice=false;

var worldRadius=6000;
var WAAG = WAAG || {};
var log=false;
var fontBlue="#80BFFF";

WAAG.Globe = function Globe(container) {

  var camera, camTarget, scene, sceneAtmosphere, renderer, w, h;
  var stats;
  var directionalLight, pointLight;
  var refGlobe;
  var matLine, matLineDashed;
  var globeRadius=worldRadius;
  var projection;
    
  var geometry;
  var tweenObject;
  var geometryStack=[];

  var curZoomSpeed = 0;
  var zoomSpeed = 10;
  var zoomDamp =1;

  var mouse = { x: 0, y: 0 }, mouseOnDown = { x: 0, y: 0 }, INTERSECTED;
  var target = { lat: 52.3734, lng: 4.8921 };
  var targetOnDown = { lat: 0, lng: 0 };
  var orbit=false;
  
  var distanceInit = 15000, distanceTarget = 15000;
  var maxDistance = 25000,  minDistance=globeRadius+1;
  
  var PI_HALF = Math.PI / 2;
  
  var cameraTween;
  var tweenActive=false; 
 
  var psWorld;	
  var pMaterial;
  var ptDotFade=10; // stepper for tail fade
  
  var cBlack, cWhite; // colors white
  
  var poolPtLive={
	ptTrams:{layer:"ptTrams", ps:null, mouseRefs:[]},
	ptBuses:{layer:"ptBuses", ps:null, mouseRefs:[]},
	ptFerrys:{layer:"ptFerrys", ps:null, mouseRefs:[]},
	ptSubways:{layer:"ptSubways", ps:null, mouseRefs:[]},
	
  };	
  var projector, raycaster;
  var mouseRefs;

  var globeInited=false;
	
  // solution for Firefox
  var mousewheelevt=(/Firefox/i.test(navigator.userAgent))? "DOMMouseScroll" : "mousewheel" //FF doesn't recognize mousewheel as of FF3.x
  var zValue=0.5;


function init () {

    container.style.color = '#fff';
    container.style.font = '13px/20px Arial, sans-serif';

    w = container.offsetWidth || window.innerWidth;
    h = container.offsetHeight || window.innerHeight;

    projection="GLOBE";
	//projection="MERCATOR";

    scene = new THREE.Scene();
		
	if(projection=="GLOBE"){
		globeRadius=worldRadius;
		 distanceInit = 15000; 
		 distanceTarget = 15000;
		 maxDistance = 25000;
		 minDistance=globeRadius+1;
		
		 
	}else if(projection=="MERCATOR"){
		 globeRadius=0;
		 distanceInit = 15000-worldRadius; 
		 distanceTarget = 15000-worldRadius;
		 maxDistance = 25000-worldRadius;
		 minDistance=1;
		 
	}
	camera = new THREE.PerspectiveCamera( 50, w / h, 0.1, maxDistance*10 );
	camera.position.z = distanceInit*10;
    scene.add( camera );
	camTarget=scene.position;
	
	refGlobe=new THREE.Object3D();
	refGlobe.name="refGlobe";
	scene.add(refGlobe);
	var mGlobe = new THREE.Mesh(  new THREE.SphereGeometry( globeRadius, 64, 36 ), new THREE.MeshNormalMaterial());
	mGlobe.visible=false;
	refGlobe.add( mGlobe );

	projector = new THREE.Projector();
	raycaster = new THREE.Raycaster();
    
    scene.add( new THREE.AmbientLight( 0xffffff ) );

	directionalLight = new THREE.DirectionalLight( 0xffffff );
	directionalLight.position.set( distanceInit, distanceInit, distanceInit );
	directionalLight.intensity=1;
	scene.add( directionalLight );

	cBlack=new THREE.Color( 0x000000 ); // line color black
	cWhite=new THREE.Color( 0xa4d7d9 ); // line color white

	matLine = new THREE.LineBasicMaterial({color: 0xa4d7d9, linewidth:0.1, vertexColors: THREE.VertexColors });

	// static particle material
	pMaterial =
	  new THREE.ParticleBasicMaterial({
	    color: 0xc0e1e9,
	    size: 1,
		sizeAttenuation: false, 
	    map: THREE.ImageUtils.loadTexture(
	      "images/textures/spark_static.png"
	    ),
	    blending: THREE.AdditiveBlending,
		depthTest: false,
	    transparent: true
	  });

	// create particles pool for live data animation
	mouseRefs=new THREE.Object3D();
	mouseRefs.name="mouseRefs";
	scene.add(mouseRefs); 
	for (var j=0; j<4; j++){
		
		var pGeo = new THREE.Geometry();
		
		var layerLive;
		var trips;
		if(j==0){layerLive="ptTrams"; trips=250}
		if(j==1){layerLive="ptBuses"; trips=1000} 
		if(j==2){layerLive="ptFerrys"; trips=10} 
		if(j==3){layerLive="ptSubways"; trips=50}  
		var fGeo=new THREE.Geometry();
		fGeo.dynamic=true;	
		
		for (var i=0; i<trips; i++){
			for (var v=0; v<ptDotFade; v++){
				var pos=new THREE.Vector3(0,0,0);
				vec3=createVector3(pos, v, 1, 0xff0000, false);
				vec3.ll=false;
				pGeo.vertices.push( vec3 );
				if(v==0){
					var mouseRef = new THREE.Mesh(  new THREE.PlaneGeometry( 0.05, 0.05, 1, 1 ));
					mouseRef.visible=false;
					mouseRefs.add(mouseRef);
				    //scene.add(mouseRef);
					poolPtLive[layerLive].mouseRefs.push(mouseRef);	
					
				}
			}

		}
		
		addParticlesDynamic(pGeo, pGeo, layerLive);

	}
	
	tweenObject= new THREE.Mesh(  new THREE.SphereGeometry( 1, 4, 4 ));
	tweenObject.name="refTweenObject";

    renderer = new THREE.WebGLRenderer({antialias: true});
    renderer.setSize(w, h);
    renderer.domElement.style.position = 'absolute';
    container.appendChild(renderer.domElement);

    container.addEventListener('mousedown', onMouseDown, false);
    container.addEventListener( 'mousemove', onDocumentMouseMove, false );
	container.addEventListener( 'dblclick', onDoubleClick, false );

    //document.addEventListener('mousewheel', onMouseWheel, false);
    document.addEventListener('keydown', onDocumentKeyDown, false);
    window.addEventListener('resize', onWindowResize, false);

	if (document.attachEvent) //if IE (and Opera depending on user setting)
	    document.attachEvent("on"+mousewheelevt, onMouseWheel)
	else if (document.addEventListener) //WC3 browsers
	    document.addEventListener(mousewheelevt, onMouseWheel, false)

    
    stats = new Stats();
	stats.domElement.style.position = 'absolute';
	stats.domElement.style.top = '0px';
	stats.domElement.style.left = w-100+'px';
	if(debug){
		container.appendChild( stats.domElement );
	}

	processWorldData("data/countries.geo.json");
		
  }

  function processWorldData(uri){
	  	  
	  d3.json(uri, function(data)
	  { 
		var pos;
		var vec3;
		var dotSize=10;
		var pGeo = new THREE.Geometry();
		data.features.forEach(function (d,p_i)
	      {
									
	    	 var coordinates = d.geometry.coordinates ;
	         coordinates.forEach(function (c, p_index)
	          {	
		  			
	        	  //var linegeo = new THREE.Geometry();
	              c.forEach(function (v, p_indexC)
	              {
	          	   if(d.geometry.type=="MultiPolygon"){
	          		 v.forEach(function (k, p_indexV)
	       	         {
	          			pos=getWorldPosition(k[1], k[0], globeRadius, projection); 
						vec3=createVector3(pos, k, dotSize, 0xffffff);
						vec3.name=d.properties.name;
						pGeo.vertices.push( vec3);
	       	         });

	          	   }else if(d.geometry.type=="Polygon"){
	          			pos=getWorldPosition(v[1], v[0], globeRadius, projection);
						vec3=createVector3(pos, v, dotSize, 0xffffff);
						vec3.name=d.properties.name;
						pGeo.vertices.push( vec3); 

	          	   }

	              });

	          });	         
	      });
	
		psWorld = new THREE.ParticleSystem( pGeo, pMaterial );
		psWorld.name="world_dots";
		
		
		scene.add(psWorld);
		//var add=addParticlesStatic(pGeo, "world", false);
	  });
  }

	addExternalApiData =function(data, dataLayer){
		var pos2D, pos3D, vec2D, vec3D;
		var pGeo2D = new THREE.Geometry();
		var pGeo3D = new THREE.Geometry();
		var lGeo2D = new THREE.Geometry();
		var lGeo3D = new THREE.Geometry();
		var dotSize = dataLayer.properties.dotSize;

		console.log("data length ="+data.strike.length);
			for (var i=0; i<data.strike.length; i++){
				var ll=[data.strike[i].lon, data.strike[i].lat];
				
				pos3D=getWorldPosition(ll[1], ll[0], globeRadius, "GLOBE"); 
				vec3D=createVector3(pos3D, ll, dotSize, 0xffffff);
				pGeo3D.vertices.push( vec3D );
				
				pos2D=getWorldPosition(ll[1], ll[0], 0, "MERCATOR");
				vec2D=createVector3(pos2D, ll, dotSize, 0xffffff);
				pGeo2D.vertices.push( vec2D );
				
			}

		dataLayer.geoRepository={lGeo2D:lGeo2D, lGeo3D:lGeo3D, pGeo2D:pGeo2D, pGeo3D:pGeo3D};
		var add=addParticlesDynamic(pGeo2D, pGeo3D, dataLayer.layer);
	}

	addLoadedData = function(dataLayer){
		
		if(dataLayer.properties.lines){
			addLines(dataLayer.geoRepository.lGeo2D, dataLayer.geoRepository.lGeo3D, dataLayer.layer);
			console.log("adding line geo from repo");

		}
		if(dataLayer.properties.dotSize>0){
			addParticlesDynamic(dataLayer.geoRepository.pGeo2D, dataLayer.geoRepository.pGeo3D, dataLayer.layer);
			console.log("adding dots geo from repo");

		}
		if(dataLayer.properties.shape){
			mergeShapes(dataLayer, true);
			console.log("adding shape geo from repo");
		}
		
	}
var geoRepository=[];	
var stackIndex=0;
addData = function (data, dataLayer){
	//$("#feedback").text("adding layer : "+layer+""); 	
	//console.log("stacked geo ="+properties.stacked);
	var dotSize=dataLayer.properties.dotSize;
	
	var pGeo2D = new THREE.Geometry();
	var pGeo3D = new THREE.Geometry();
	var lGeo2D = new THREE.Geometry();
	var lGeo3D = new THREE.Geometry();
	var mergedGeoStack=[]; //shape 2D region loader
	
	
	var i;
	for(i=0; i<geoRepository.length; i++){
		if(geoRepository[i].layer==dataLayer.layer){
			
			pGeo2D.vertices = geoRepository[i].geoTypes.pGeo2D.vertices;
			pGeo3D.vertices = geoRepository[i].geoTypes.pGeo3D.vertices;
			lGeo2D.vertices = geoRepository[i].geoTypes.lGeo2D.vertices;
			lGeo3D.vertices = geoRepository[i].geoTypes.lGeo3D.vertices;
			mergedGeoStack = geoRepository[i].geoTypes.mergedGeoStack;
		}
	}
	

	i=0;		
	while (i<scene.children.length)
	{		
		if(scene.children[i].name==dataLayer.layer){
			scene.remove(scene.children[i]);
			i--;
		}
		i++;
	}
	
	if(dataLayer.properties.stacked){
		dataLayer.properties.stackIndex++;
	}else{
		dataLayer.properties.stackIndex=0;
	}
	
	if(dataLayer.properties.shape){
		var shapes2D;
		for (var i=0; i<scene.children.length; i++){
			if(scene.children[i].name==dataLayer.layer+"_stack_loader"){
					shapes2D=scene.children[i];
					break;
			}
		}
				
		if(shapes2D instanceof THREE.Object3D){
			// shape is onstage --> do nothing
			
		}else{
			shapes2D=new THREE.Object3D();
			shapes2D.name=dataLayer.layer+"_stack_loader";
			scene.add(shapes2D);
		}
		
		
	}
	
	
	var pos, pos2D, pos3D, posInvisible;
	var vec2D, vec3D;
	data.forEach(function (d, p_i)
    {
	
	var coordinates = d.geom.coordinates;
		
	if(d.geom.type=="Point" || d.geom.type=="MultiPoint"){
			
		if(d.geom.type=="MultiPoint"){	
			
			coordinates.forEach(function (c, p_index)
			{
				
				pos2D=getWorldPosition(c[1], c[0], 0, "MERCATOR");
				vec2D=createVector3(pos2D, c, dotSize, 0xffffff);
				
				pos3D=getWorldPosition(c[1], c[0], globeRadius, "GLOBE"); 
				vec3D=createVector3(pos3D, c, dotSize, 0xffffff);
								
				
				if(d.layer_id=="divv"){
					if(d.layers.divv.data!=null){
						var cw=getColorWidth(d.layers.divv.data.traveltime, d.layers.divv.data.traveltime_ff, d.layers.divv.data.velocity, dotSize, projection)
						vec2D.color=vec3.color=cw.c;
						vec2D.pointSize=vec3.pointSize=cw.w;
					
					}else{
						vec2D.pointSize=vec3.pointSize=dotSize;
					}
				}
				pGeo2D.vertices.push( vec2D );
				pGeo3D.vertices.push( vec3D );
				
			});
			
		}else{
			
			pos2D=getWorldPosition(d.geom.coordinates[1], d.geom.coordinates[0], 0, "MERCATOR"); 
			vec2D=createVector3(pos2D, d.geom.coordinates, dotSize, 0xffffff);
			
			pos3D=getWorldPosition(d.geom.coordinates[1], d.geom.coordinates[0], globeRadius, "GLOBE"); 
			vec3D=createVector3(pos3D, d.geom.coordinates, dotSize, 0xffffff);
			
			pGeo2D.vertices.push( vec2D );
			pGeo3D.vertices.push( vec3D );
	
		}

	}else if (d.geom.type=="MultiLineString" || d.geom.type=="LineString"){
		
		if(d.geom.type=="LineString"){	
			//var linegeo = new THREE.Geometry();
			coordinates.forEach(function (c, p_index)
			{
				pos2D=getWorldPosition(c[1], c[0], 0, "MERCATOR");
				vec2D=createVector3(pos2D, c, dotSize, 0xffffff);
				
				pos3D=getWorldPosition(c[1], c[0], globeRadius, "GLOBE"); 
				vec3D=createVector3(pos3D, c, dotSize, 0xffffff);
				posInvisible=getWorldPosition(c[1], c[0], globeRadius-zValue, "GLOBE");
				
				lGeo2D=addLineVertices(p_index, d.geom.coordinates.length-1, lGeo2D, pos2D, "2D");
				lGeo3D=addLineVertices(p_index, d.geom.coordinates.length-1, lGeo3D, pos3D, posInvisible);
					
				
				if(d.layer_id=="divv"){
					if(d.layers.divv.data!=null){
						var cw=getColorWidth(d.layers.divv.data.traveltime, d.layers.divv.data.traveltime_ff, d.layers.divv.data.velocity, dataLayer.properties.dotSize, dataLayer.layer)
						vec2D.color=vec3.color=cw.c;
						vec2D.pointSize=vec3.pointSize=cw.w;
					
					}else{
						vec2D.pointSize=vec3.pointSize=dotSize;
					}
				}
				pGeo2D.vertices.push( vec2D );
				pGeo3D.vertices.push( vec3D );
				
			});
	
		}else if(d.geom.type=="MultiLineString"){	
			//var linegeo = new THREE.Geometry();
			coordinates.forEach(function (c, p_index)
			{
				
				c.forEach(function (v, p_indexC )
				{		
					
					pos2D=getWorldPosition(v[1], v[0], 0, "MERCATOR");
					pos3D=getWorldPosition(v[1], v[0], globeRadius, "GLOBE");
					
					posInvisible=getWorldPosition(c[1], c[0], globeRadius-zValue, "GLOBE");
					 
					lGeo2D=addLineVertices(p_indexC, d.geom.coordinates[p_index].length-1, lGeo2D, pos2D, "2D");
					lGeo3D=addLineVertices(p_indexC, d.geom.coordinates[p_index].length-1, lGeo3D, pos3D, posInvisible);	
					
					vec2D=createVector3(pos2D, c, dotSize, 0xffffff);
					vec3D=createVector3(pos3D, c, dotSize, 0xffffff);
										
					if(d.layer=="divv.traffic"){
						//console.log("travel time ="+d.cdk_id+" = "+d.layers["divv.traffic"].data.traveltime+" --> "+d.layers["divv.traffi"].data.traveltime_freeflow);
						if(d.layers["divv.traffic"].data!=null){
							var cw=getColorWidth(d.layers["divv.traffic"].data.traveltime, d.layers["divv.traffic"].data.traveltime_freeflow, d.layers["divv.traffic"].data.velocity, dataLayer.properties.dotSize, dataLayer.layer)
							vec2D.color=vec3.color=cw.c;
							vec2D.pointSize=vec3.pointSize=cw.w;
						
						}else{
							vec2D.pointSize=vec3.pointSize=1;
						}

					}
					pGeo2D.vertices.push( vec2D );
					pGeo3D.vertices.push( vec3D );
		
				});

			});			
		}
														
	}else if (d.geom.type=="MultiPolygon" || d.geom.type=="Polygon" ){
		
		coordinates.forEach(function (c, p_index)
        {
			  
        	  //var linegeo = new THREE.Geometry();
              c.forEach(function (v, p_indexC )
              {
				
          	   if(d.geom.type=="MultiPolygon" ){
				var sGeo2D = new THREE.Geometry();
				var sGeo3D = new THREE.Geometry();
				var meshMerged;
          		 v.forEach(function (k, p_indexV)
       	         {
          			pos2D=getWorldPosition(k[1], k[0], 0, "MERCATOR");
					pos3D=getWorldPosition(k[1], k[0], globeRadius, "GLOBE");      
          	    	posInvisible=getWorldPosition(c[1], c[0], globeRadius-zValue, "GLOBE");
					
					lGeo2D=addLineVertices(p_indexV, d.geom.coordinates[p_index][p_indexC].length-1, lGeo2D, pos2D, "2D");
					lGeo3D=addLineVertices(p_indexV, d.geom.coordinates[p_index][p_indexC].length-1, lGeo3D, pos2D, posInvisible);
					
					vec3D=createVector3(pos2D, k, dotSize, 0xffffff);
					vec3D=createVector3(pos3D, k, dotSize, 0xffffff); 
					
					pGeo2D.vertices.push( vec2D );
					pGeo3D.vertices.push( vec3D );
					
					pos2D=getWorldPosition(k[1], k[0], 0, "MERCATOR");
					pos3D=getWorldPosition(k[1], k[0], globeRadius, "GLOBE");
					
					sGeo2D.vertices.push( pos2D );
					

					
       	         });

					if(dataLayer.properties.shape==true){
							
							var shape2D = new THREE.Shape( sGeo2D.vertices );
							var shapeGeo = new THREE.ShapeGeometry( shape2D );  
							//var matShape=new THREE.MeshPhongMaterial( { ambient: 0xccfffff, color: 0x669999,  specular: 0xffffff, shininess: 60, shading: THREE.SmoothShading, transparent: true, wireframe:false} );
							//var mesh = new THREE.Mesh( shapeGeo, matShape);

							var mesh = new THREE.Mesh( shapeGeo, new THREE.MeshFaceMaterial());

							mesh.material.opacity=0.1+(Math.random()*0.25);
							mesh.alphaOrg=mesh.material.opacity;
							//mesh.data=d;
							mesh.name=dataLayer.layer+"_shape";
							mesh.dynamic=true;
							//console.log("adding mesh "+mesh.name);
							var color=new THREE.Color(  0xffffff  );
							color.setHSL( 0.5, 0.759, 0.1+(Math.random()*0.5) );
							//color.data=d;
							for (var i = 0; i < mesh.geometry.faces.length; i++) {
								mesh.geometry.faces[i].color =  color;
	
							};
							var mergedGeo = new THREE.Geometry();
							mergedGeo.data=d;
							THREE.GeometryUtils.merge(mergedGeo, mesh);
														
							//subMergedGeo.computeFaceNormals();
							var matMerged = new THREE.MeshBasicMaterial( { vertexColors: THREE.FaceColors, shading: THREE.SmoothShading } );
							meshMerged = new THREE.Mesh( mergedGeo, matMerged);
							
							if(projection=="GLOBE"){
								for(var i=0; i<meshMerged.geometry.vertices.length; i++){
																			
									var ll2D = getLatLong(meshMerged.geometry.vertices[i], globeRadius, "MERCATOR")
									var ll=[ll2D.lat, ll2D.lng]
									mergedGeo.vertices[i].ll=ll;
									var pos3D=getWorldPosition(ll[0], ll[1], globeRadius, projection);
																										
									meshMerged.geometry.vertices[i].x=pos3D.x;
									meshMerged.geometry.vertices[i].y=pos3D.y;
									meshMerged.geometry.vertices[i].z=pos3D.z;	
								}
							}
												
							mergedGeoStack.push(mergedGeo);
							shapes2D.add(meshMerged);
							$("#feedback").text("adding  :"+d.cdk_id+" --> datapoints :"+mesh.geometry.vertices.length);

						}

          	   }else if (d.geom.type=="Polygon" ){
          		
					pos2D=getWorldPosition(v[1], v[0], 0, "MERCATOR");
					pos3D=getWorldPosition(v[1], v[0], globeRadius, "GLOBE");
					posInvisible=getWorldPosition(c[1], c[0], globeRadius-zValue, "GLOBE");		
										
					lGeo2D=addLineVertices(p_indexC, d.geom.coordinates[p_index].length-1, lGeo2D, pos2D, "2D");
					lGeo3D=addLineVertices(p_indexC, d.geom.coordinates[p_index].length-1, lGeo3D, pos3D, posInvisible);

					vec2D=createVector3(pos2D, v, dotSize, 0xffffff);						
					vec3D=createVector3(pos3D, v, dotSize, 0xffffff);

					pGeo2D.vertices.push( vec2D );
					pGeo3D.vertices.push( vec3D );
					
					//pos2D=getWorldPosition(k[1], k[0], globeRadius, "MERCATOR");
					sGeo2D.vertices.push( pos2D );
          	   }

              });

          });	
		}
				

	});
	
	if(dataLayer.properties.stacked && (dataLayer.properties.stackIndex<dataLayer.properties.stackAmount)){
		
		var perc=parseInt( (dataLayer.properties.stackIndex/dataLayer.properties.stackAmount)*100 );
		$( "#progressbar" ).progressbar({
	      value: perc
	    });
		
	}else{
		$( "#progressbar" ).progressbar({
	      value: 0
	    });
		
	}
	
	var addToGeoRepository=true;			
	// when geo added by mouseover action
	if(dataLayer.layer=="mouse_info"){
		addToGeoRepository=false;
	}
	
	
	i=0;		
	while (i<geoRepository.length)
	{
		if(geoRepository[i].layer==dataLayer.layer){
			geoRepository.splice(i,1);
			i--;
		}
		i++;
		
	}
	
	var geoTypes={lGeo2D:lGeo2D, lGeo3D:lGeo3D, pGeo2D:pGeo2D, pGeo3D:pGeo3D, mergedGeoStack:mergedGeoStack};
	dataLayer.geoRepository=geoTypes;	
	var loadedGeometries={layer:dataLayer.layer, geoTypes:geoTypes};

	//strore geo temp for stacked loading
	if(addToGeoRepository){
		geoRepository.push(loadedGeometries);
	}
	
	if(dataLayer.properties.lines){
		addLines(lGeo2D, lGeo3D, dataLayer.layer );
	}

	if(dotSize>0){ 
		var add=addParticlesDynamic(pGeo2D, pGeo3D, dataLayer.layer);
	}
	
	if(dataLayer.properties.stacked && dataLayer.properties.shape){
		//console.log("stack index ="+shapes2D.stackIndex);
		if(dataLayer.properties.stackIndex==dataLayer.properties.stackAmount){
			mergeShapes(dataLayer, false);
			
		}
	
	}else if(dataLayer.properties.stacked==false && dataLayer.properties.shape){
		mergeShapes(dataLayer.layer, false);
		
	}


}


function mergeShapes(dataLayer, merged){
		
		for (var i=0; i<scene.children.length; i++){
			if(scene.children[i].name==dataLayer.layer+"_stack_loader"){
				scene.remove(scene.children[i]);
				break;
			}
		}
		var mesh;		
		if(merged==false){
			
			var mergedGeo=new THREE.Geometry();
			var fIndex=0;
			for(var i=0; i<dataLayer.geoRepository.mergedGeoStack.length; i++){
				THREE.GeometryUtils.merge(mergedGeo, dataLayer.geoRepository.mergedGeoStack[i]);	
				for(var f=fIndex; f<mergedGeo.faces.length; f++){
					mergedGeo.faces[f].data=dataLayer.geoRepository.mergedGeoStack[i].data;
					fIndex++;

				}

			}
			mergedGeo.computeFaceNormals();	
			var matMerged = new THREE.MeshBasicMaterial( { vertexColors: THREE.FaceColors, shading: THREE.SmoothShading } );
			mesh=new THREE.Mesh( mergedGeo, matMerged);
			mesh.name=dataLayer.layer;
			mesh.dynamic=true;

			var ll; 
			var pos2D=new THREE.Vector3();
			var pos3D=new THREE.Vector3();
		
			if(mesh.geometry.vertices[0].z==0){
				geo2D=mesh.geometry;
			}else{
				geo3D=mesh.geometry;
			}
								
			for(var i=0; i<mesh.geometry.vertices.length; i++){
				if(mesh.geometry.vertices[i].z==0){
				
					ll = getLatLong(mesh.geometry.vertices[i], worldRadius, "MERCATOR");
					ll=[ll.lat, ll.lng];
					pos2D.x=mesh.geometry.vertices[i].x;
					pos2D.y=mesh.geometry.vertices[i].y;
					pos2D.z=mesh.geometry.vertices[i].z;
					
					pos3D=getWorldPosition(ll[0], ll[1], globeRadius, "GLOBE");
					mesh.geometry.vertices[i].pos2D=pos2D;
					mesh.geometry.vertices[i].pos3D=pos3D;
				
				}else{
				
					ll = getLatLong(mesh.geometry.vertices[i], worldRadius, "GLOBE");
					ll=[ll.lat, ll.lng];
					pos2D=getWorldPosition(ll[0], ll[1], globeRadius, "MERCATOR");
					pos2D.z=0;					
					
					pos3D.x=mesh.geometry.vertices[i].x;
					pos3D.y=mesh.geometry.vertices[i].y;
					pos3D.z=mesh.geometry.vertices[i].z;
					mesh.geometry.vertices[i].pos2D=pos2D;
					mesh.geometry.vertices[i].pos3D=pos3D;
				
				}
		
							
			}
			
			dataLayer.geoRepository.sGeo=mesh;
			
		
		}else{
			mesh=dataLayer.geoRepository.sGeo;
			for(var i=0; i<mesh.geometry.vertices.length; i++){
				if(projection=="GLOBE"){
					pos=mesh.geometry.vertices[i].pos3D;
					
				}else if(projection=="MERCATOR"){
					pos=mesh.geometry.vertices[i].pos2D;
				}
				mesh.geometry.vertices[i].x=pos.x;
				mesh.geometry.vertices[i].y=pos.y;
				mesh.geometry.vertices[i].z=pos.z;
							
			}
			
			mesh.geometry.verticesNeedUpdate=true;
			
		}

		var object3D=new THREE.Object3D();
		object3D.name=dataLayer.layer;
		object3D.add(mesh);
		scene.add(object3D);
		console.log("adding shapes merged");
		$( "#progressbar" ).progressbar({
	      value: 0
	    });
		$("#feedback").text("");

}

function addLineVertices(v_index, v_last, lGeo, pos, posInvisible){
	
	if(posInvisible=="2D"){
		posInvisible.z=zValue;
	}
		
	if( v_index==0 ){
		lGeo.vertices.push(posInvisible);
		lGeo.colors.push(cBlack);
		lGeo.vertices.push(pos);
		lGeo.colors.push(cWhite);
		
	}else if( v_index==v_last) {
		lGeo.vertices.push(pos);
		lGeo.colors.push(cWhite);
		lGeo.vertices.push(posInvisible);
		lGeo.colors.push(cBlack);
	}else{
		lGeo.vertices.push(pos);
		lGeo.colors.push(cWhite);
	}
	
	return lGeo;
	
	
}

function addLines(geo2D, geo3D, layer){
	var lGeo;
	if(projection=="GLOBE"){
		lGeo=geo3D;
	}else{
		lGeo=geo2D;
	}
	if(lGeo.vertices.length==0)return;

	//var line = new THREE.Line(lGeo, matLine, THREE.LinePieces);
	var line = new THREE.Line(lGeo, matLine);
	line.dynamic=true;
	line.name=layer;
	scene.add(line);
	
	return true;
	//console.log("adding line :"+layer);
	
}

function addParticlesDynamic(geo2D, geo3D, layer){
	var pGeo;
	if(projection=="GLOBE"){
		pGeo=geo3D;
	}else{
		pGeo=geo2D;
	}
	if(pGeo.vertices.length==0)return;
	
	var ps, vertices, values_size, values_color;
	
	var attributes = {
		size: {	type: 'f', value: [] },
		customColor: { type: 'c', value: [] }
			
	};
	
	var uniforms = {
		amplitude: { type: "f", value: 1 },
		color:     { type: "c", value: new THREE.Color( 0xffffff ) },
		texture:   { type: "t", value: 0, texture: THREE.ImageUtils.loadTexture( "images/textures/spark.png" ) },
	};
	
	var shader = new THREE.ShaderMaterial( {

		uniforms: 		uniforms,
		attributes:     attributes,
		vertexShader:   document.getElementById( 'vertexshader' ).textContent,
		fragmentShader: document.getElementById( 'fragmentshader' ).textContent,

		blending: 		THREE.AdditiveBlending,
		depthTest: 		false,
		transparent:	true,
		sizeAttenuation: true

	});

	ps = new THREE.ParticleSystem( pGeo, shader );
	values_size = ps.material.attributes.size.value;
	values_color = ps.material.attributes.customColor.value;
	vertices = ps.geometry.vertices;	
	ps.dynamic = true;
	ps.name=layer;
		
	//console.log(vertices.length);
	for( var v = 0; v < vertices.length; v++ ) {

		values_size[ v ] = vertices[v].pointSize;
		values_color[ v ] = new THREE.Color( vertices[v].color );
		values_color[ v ].setHSL( 0.5, 0.5, 0.3 );	
		
		if (layer=="ptTrams"){
			values_color[ v ].setHSL( 0.8, 0.5, 0.25 );
		}else if (layer=="ptBuses"){
			values_color[ v ].setHSL( 0.0, 0.5, 0.4 );
		}else if (layer=="ptFerrys"){
			values_color[ v ].setHSL( 0.66, 0.5, 0.25 );
		}else if (layer=="ptSubways"){
			values_color[ v ].setHSL( 0.3, 0.5, 0.25 );
		}else if (layer=="ptFerrys"){
			values_color[ v ].setHSL( 0.6, 0.759, 0.585 );
		}else if(layer=="drone_attacks"){
			values_color[ v ].setHSL( 0.0, 0.5, 0.4 );
		}

	}

	if(layer!="trafic_flow_adam_recorded"){
		$("#feedback").html("adding layer :"+layer+" --> datapoints :"+ps.geometry.vertices.length);
	}

	
	if(layer=="ptTrams" || layer=="ptBuses" || layer=="ptFerrys" || layer=="ptSubways"){
	
		poolPtLive[layer].ps=ps;
		$("#feedback").html("");
	}

	//console.log("adding ps:"+layer);
	scene.add( ps );
	
	return true;

	
}


// function addParticlesStatic(dataLayer){
// 		
// 	var ps = new THREE.ParticleSystem( pGeo, pMaterial );
// 	ps.dynamic=true;
// 	ps.dataLayer=dataLayer;
// 	ps.name=layer+"_dots";
// 	scene.add( ps );
// 	
// 	if(layer.slice(0,3)=="nl_"){
// 		ps.name="nl_ptstops_dots";
// 		//console.log("renaming nl layer");
// 	};
// 
// 
// 	var add=true;
// 	return add; 
// 
// 	
//   }

  function zoom(delta) {
	var zoom;
	if(projection=="GLOBE"){
		zoom=10;
	}else if(projection=="MERCATOR"){
		zoom=5;
	}
	
    distanceTarget -= (delta*(zoom*zoomDamp));
    distanceTarget = distanceTarget > maxDistance ? maxDistance : distanceTarget;
    distanceTarget = distanceTarget < minDistance ? minDistance : distanceTarget;
  }

  function animate() {
    requestAnimationFrame(animate);
    render();
	if(debug){
		stats.update();
	}
	
  }

  function render() {
	
	TWEEN.update();
	
	var d=getDistance(camera.position, projection);	

	zoomDamp=(d-globeRadius)/(distanceInit-globeRadius);

	for(var i=0; i<scene.children.length; i++){
			
		if(scene.children[i].name=="world_dots"){
			
			if(scene.children[i].visible && d-globeRadius<=1000){
				scene.children[i].visible=false;
				break;
			}else if( !scene.children[i].visible && d-globeRadius>1000 ){
				scene.children[i].visible=true;
				break;	
			}
				
		}
	
	}

	var smooth;
	if(globeInited){
		smooth=0.05;
	}else{
		smooth=0.1;
	}
	
	var camLL=getLatLong(camera.position, d, projection);
	camLL.lat += (target.lat - camLL.lat) * smooth ;
	camLL.lng += (target.lng - camLL.lng) * smooth ;
	d += (distanceTarget - d) * smooth;
	
	var targetLL=camLL;
	targetLL.lat += (target.lat - camLL.lat) * (smooth*2) ;
	targetLL.lng += (target.lng - camLL.lng) * (smooth*2) ;
	
	var posCam = getWorldPosition(camLL.lat, camLL.lng , d, projection);
	//var posTarget = getWorldPosition(targetLL.lat, targetLL.lng , globeRadius, projection);
	
	if(projection=="GLOBE"){
		//camTarget.x=posTarget.x;
		//camTarget.y=posTarget.y;
		//camTarget.z=posTarget.z;
		
		camTarget.x=0;
		camTarget.y=0;
		camTarget.z=0;
		
	}else if(projection=="MERCATOR"){
		posCam.z+=globeRadius;
		
		//camTarget.x=posTarget.x;
		//camTarget.y=posTarget.y;
		camTarget.x=posCam.x;
		camTarget.y=posCam.y;
		
		camTarget.z=0;
	}	
	camera.position.set(posCam.x, posCam.y, posCam.z);
	camera.lookAt( camTarget );
	directionalLight.position.set( camera.position.x, camera.position.y, camera.position.z );
    

	if(projectionTweenActive){
		psWorld.geometry.verticesNeedUpdate = true;
	}
	
	effectsUpdate();
	//camera.updateProjectionMatrix();
	renderer.render(scene, camera);

  }

  focusCity = function(targetLL){
	tweenFocusCity(targetLL);
  } 

  var tween;

  function tweenFocusCity(targetLL, tweenTime){
	var tweenTime=2000;	
	//tweenActive=true;
	var d=getDistance(camera.position, projection);
	distanceTarget=globeRadius+targetLL.d;
	var currentLatLong=getLatLong(camera.position, d, projection);

	tweenObject.position.x=currentLatLong.lat;
	tweenObject.position.y=currentLatLong.lng;
	tweenObject.position.z=d;
	var tweenTarget=targetLL;
	
	target=targetLL;

  }

  	

  toggleProjection = function (){
	
	var d=getDistance(camera.position, projection);
	var camLL=getLatLong(camera.position, d, projection);

	if(projection=="GLOBE"){
		projection="MERCATOR";
		globeRadius=0;
		distanceInit = 15000-worldRadius; 
		distanceTarget = 15000-worldRadius;
		maxDistance = 25000-worldRadius;
		minDistance=1;
	}else{
		projection="GLOBE";
		globeRadius=worldRadius;
		distanceInit = 15000; 
		distanceTarget = 15000;
		maxDistance = 25000;
		minDistance=globeRadius+1;
	}
	
	var i=0;
	
	while (i<scene.children.length)
	{
		for(var j=0; j<layerStack.length; j++){
			if(scene.children[i].name==layerStack[j].layer){
				console.log("removing child :"+scene.children[i].name);
				scene.remove(scene.children[i]);
				i--;
			}
		}

		i++;		
		
		
	}
	
	firstTweenDone=false;
	for(var i=0; i<psWorld.geometry.vertices.length; i++){
					
		var ll=psWorld.geometry.vertices[i].ll;
		var pos=getWorldPosition(ll[1], ll[0], globeRadius, projection);
	
		var tween = new TWEEN.Tween( psWorld.geometry.vertices[i] ).to( {
			x: pos.x,
			y: pos.y,
			z: pos.z }, 1000 )
			.easing( TWEEN.Easing.Quartic.EaseOut )
			.start()
			.onUpdate(function(){projectionTweenActive=true; })
			.onComplete(function(){
				projectionTweenActive=false;
				tweenActive=false;
				updateGeometryProjection();
			
		});

			
	}

	var pos = getWorldPosition(camLL.lat, camLL.lng , d, projection);
	camera.position.set(pos.x, pos.y, pos.z);
	
  }

var firstTweenDone=true;
function updateGeometryProjection(){
	
	
	if(firstTweenDone==true){
		return;
	}
	firstTweenDone=true;
	console.log("updating layers");
	
	for(var i=0; i<layerStack.length; i++){

		getApiData(layerStack[i]);
		
	}
	
	
	
}

var projectionTweenActive=false;

var cpuRefreshTime=66;
var timerPositions=setInterval(function(){livePositionUpdate()}, cpuRefreshTime);
//var timerEffects=setInterval(function(){effectsUpdate()}, 33);
var mouseRayActive=false;
function effectsUpdate(){
	var i;
	for(key in poolPtLive){
		if(poolPtLive[key].ps.visible){
			for (var i=0; i<poolPtLive[key].ps.geometry.vertices.length; i++){
				var pointSize=poolPtLive[key].ps.geometry.vertices[i].pointSize;
				poolPtLive[key].ps.material.attributes.size.value[i] = pointSize + ( (-0.05*pointSize)+(Math.random()*(0.1*pointSize)));
			}
			poolPtLive[key].ps.material.attributes.size.needsUpdate = true;
			poolPtLive[key].ps.geometry.verticesNeedUpdate = true;
			
		}
	};

	// for(var i=0; i<scene.children.length; i++){
	// 		if(scene.children[i].name=="trafic_flow_adam" || scene.children[i].name=="trafic_flow_adam_recorded"){
	// 			if(scene.children[i] instanceof THREE.ParticleSystem){
	// 				for (var j=0; j<scene.children[i].geometry.vertices.length; j++){
	// 					var pointSize=scene.children[i].geometry.vertices[j].pointSize;
	// 					
	// 					scene.children[i].material.attributes.size.value[j]=scene.children[i].geometry.vertices[j].pointSize + ((-pointSize/2)+(Math.random()*pointSize));
	// 					//scene.children[i].material.attributes.size.value[j]=(Math.random()*10);
	// 				}
	// 				scene.children[i].material.attributes.size.needsUpdate = true;
	// 				
	// 			}
	// 
	// 		}
	// 
	// 	}
	
	
}

function livePositionUpdate()
{
	var s, i, j, t;
		
	if(layerStack.length==0){
		
		for(key in poolPtLive){
			poolPtLive[key].ps.visible=false;
		};
		
		return;
	}
		
	var liveIndex=-1;
	
	for(i=0; i<layerStack.length; i++){
		var liveLayer=layerStack[i].layer.search("_live");
		
		if(liveLayer>0){
			liveIndex=i;
		}
		
	}
		
	if(liveIndex==-1){
		for(key in poolPtLive){
			poolPtLive[key].ps.visible=false;
		};
		
		return;		
	}else{
		for(key in poolPtLive){
			if(poolPtLive[key].layer=="ptTrams"){
				poolPtLive[key].ps.visible=subsLive.tram;
			}else if(poolPtLive[key].layer=="ptBuses"){
				poolPtLive[key].ps.visible=subsLive.bus;
			}else if(poolPtLive[key].layer=="ptFerrys"){
				poolPtLive[key].ps.visible=subsLive.ferry;
			}else if(poolPtLive[key].layer=="ptSubways"){
				poolPtLive[key].ps.visible=subsLive.subway;
			}

		};

	}
				
	for(var s=0; s<ptSchedules.length; s++){
						
		if(layerStack[liveIndex].layer==ptSchedules[s].layer){
			ptSchedules[s].layer.visible=true;

			var dateNow=new Date();
			var tnow=parseInt(dateNow.getTime());

			var actualTrips=0;
			var lineName, lbus, ltram, lferry, lsubway, modalitie;
			var trips = tripstrams = tripsbuses = tripsferrys = tripssubways=0;
			var ps, mouseRef;
			for (i=0; i< ptSchedules[s].lines.length; i++){
					
				var line=ptSchedules[s].lines[i].cdk_id.slice(0,13);
	
					lineName=ptSchedules[s].lines[i].name.toLowerCase()
					lbus=lineName.search("bus");
					ltram=lineName.search("tram");
					lferry=lineName.search("ferry");
					lsubway=lineName.search("subway");

						if(lbus>0){
							modalitie="bus";
							tripsbuses=setPositionsPt(s, i, actualTrips, tnow, "ptBuses", tripsbuses, ptSchedules[s].scale.bus);
							
						}else if(ltram>0){
							modalitie="tram";
							tripstrams=setPositionsPt(s, i, actualTrips, tnow, "ptTrams", tripstrams, ptSchedules[s].scale.tram);

						}else if(lferry>0){
							modalitie="ferry";
							tripsferrys=setPositionsPt(s, i, actualTrips, tnow, "ptFerrys", tripsferrys, ptSchedules[s].scale.ferry);

						}else if(lsubway>0){
							modalitie="subway";
							tripssubways=setPositionsPt(s, i, actualTrips, tnow, "ptSubways", tripssubways, ptSchedules[s].scale.subway);

						}else{
							
							modalitie="unknown";
						}

			}
			
			//console.log("update vertices");
			actualTrips=tripsbuses+tripstrams+tripsferrys+tripssubways;

			// can be better checked
			if(tripsbuses>1000  ){				
				ptSchedules[s].scale.bus=1000/tripsbuses;
			}

			//console.log("actual trips :"+actualTrips+"--> buses :"+tripsbuses+" trams :"+tripstrams+" ferrys :"+tripsferrys+" subways:"+tripssubways);
			if(tripsLoaded==tripsToload){
			
				var txt="Actual trips :"+actualTrips+" --> ";
				txt+="bus: "+tripsbuses+" - tram: "+tripstrams+" - ferry: "+tripsferrys+" - subway: "+tripssubways;
				$("#feedback").html(txt);
			}
			
		}
	}

}
 

function setPositionsPt(mainIndex, lineIndex, actualTrips, tnow, modalitie, lineTrips, scale){
	
	var lineData=ptSchedules[mainIndex].lines[lineIndex];
	
	if(lineData.schedules==null)return lineTrips;
	
	if(lineData.indexRemember!=undefined && lineData.indexRemember>0){
		indexRemember=lineData.indexRemember;
	}else{
		indexRemember=0;
	}
	//indexRemember=0;
	for (j=indexRemember; j< lineData.schedules.trips.length; j++){
	
		var tripStart=lineData.schedules.trips[j][0][1];
		var lastIndex=lineData.schedules.trips[j].length-1;
		var tripEnd=lineData.schedules.trips[j][lastIndex][1];

		if(tripStart>tnow){
			return lineTrips;	
		}else if (tripEnd<tnow){
			//gvbPtLines[lineIndex].indexRemember=j;
			lineData.indexRemember=j-1;
		}else if(tripStart<=tnow && tripEnd>tnow){
				
				// trip riding
				for(t=0; t<lineData.schedules.trips[j].length; t++){	
					var tprev=lineData.schedules.trips[j][t][1];
					
					if(tprev<=tnow && t<lineData.schedules.trips[j].length){
						var tnext=lineData.schedules.trips[j][t+1][1];
						
						if(tnext>tnow){
						
							var tnext=lineData.schedules.trips[j][t+1][1];
							var delay=lineData.schedules.trips[j][t+1][2];
							//console.log("stop "+t+" = "+lineData.ptstops[t].name);
							var tl=tnext-tprev;
							var ta=tnext-tnow;
							var p=(tnext-tnow)/tl;
							
														
							var tmax=1;
							if(tl>150000){
								tmax=150000/tl;
							}
							var  tmin=1;
							// if(tl<120000){
							//tmin=120000/tl;
								//console.log("tmin ="+tmin);
							//}														
							lineTrips++;
							
							var fade=Math.round(ptDotFade*scale);
						
							var verticesIndex=(lineTrips*fade)+fade;
							
							if(verticesIndex>=poolPtLive[modalitie].ps.geometry.vertices.length){
								//console.log("more vertices needed for :"+modalitie);
								return lineTrips;
							}
							
							var posPrev =lineData.geom.coordinates[t][projection];
							var posNext =lineData.geom.coordinates[t+1][projection];
							
														
							for	(var f=0; f<fade; f++){
								
								var posX =posNext.x-((p/scale)*(posNext.x-posPrev.x));
								var posY =posNext.y-((p/scale)*(posNext.y-posPrev.y));
								var posZ =posNext.z-((p/scale)*(posNext.z-posPrev.z));
								
								poolPtLive[modalitie].ps.geometry.vertices[verticesIndex-f].x=posX;
								poolPtLive[modalitie].ps.geometry.vertices[verticesIndex-f].y=posY;
								poolPtLive[modalitie].ps.geometry.vertices[verticesIndex-f].z=posZ;
								
								var pointSize= 0.5 - (f/(scale*20));
								poolPtLive[modalitie].ps.geometry.vertices[verticesIndex-f].pointSize=pointSize;
								poolPtLive[modalitie].ps.material.attributes.size.value[verticesIndex-f] = pointSize;

								
								p+=(tmax*(0.025*tmin))/scale;
																
								if(f==0){
									poolPtLive[modalitie].mouseRefs[lineTrips].position.set(posX, posY, posZ);
									poolPtLive[modalitie].mouseRefs[lineTrips].lookAt(camera.position);
									
									poolPtLive[modalitie].mouseRefs[lineTrips].layer="ptlive";
									poolPtLive[modalitie].mouseRefs[lineTrips].additionalGeo=true;									
									poolPtLive[modalitie].mouseRefs[lineTrips].name=lineData.name;
									poolPtLive[modalitie].mouseRefs[lineTrips].timeleft=ta;
									
									if(lineData.ptstops){
										poolPtLive[modalitie].mouseRefs[lineTrips].laststop=lineData.ptstops[lineData.ptstops.length-1].name;
										poolPtLive[modalitie].mouseRefs[lineTrips].nextstop=lineData.ptstops[t+1].name;

										poolPtLive[modalitie].mouseRefs[lineTrips].delay=delay;
										poolPtLive[modalitie].mouseRefs[lineTrips].geom=lineData.geom;
										//poolPtLive[modalitie].mouseRefs[lineTrips].visible=true;
									}

								}
						}

					}

				 }
		
			 }
				
		}

	}

	return lineTrips;
	
  }

  function rayDetectObjects(mouseRay, action){
	    //return;
		if( orbit )return;
		if(layerStack.length==0)return;

		
		var intersectObjects;
		var intersects;
		var meshFace=false;
		var onStage=false;
		
		if(action=="mouseOver" && layerStack.length>0){
			//console.log("cbs search ="+layerStack[0].layer.search("testje"));
			
			if(layerStack[0].layer.search("pt_live")>1){
				intersectObjects=mouseRefs;
				onStage=true;
			}else if(layerStack[0].layer.search("cbs_")>=0){
				meshFace=true;
					for(var i=0; i<scene.children.length; i++){
						if(scene.children[i] instanceof THREE.Object3D){	
							if(layerStack[0].layer==scene.children[i].name ){
								intersectObjects=scene.children[i];
								onStage=true;
								break;
							}

						}
					}
				}
				
		}else{
			
			return;
		}

		
		if(onStage==false) {
			tooltip.hide()
			return;
			
		}
		
		var vector = new THREE.Vector3( mouseRay.x, mouseRay.y, 1 );
		projector.unprojectVector( vector, camera );
		raycaster.set( camera.position, vector.sub( camera.position ).normalize() );
		intersects = raycaster.intersectObjects( intersectObjects.children );

		if ( intersects.length > 0 ) {
			//console.log("intersects.length ="+intersects.length);
			if(meshFace){

				if ( INTERSECTED != intersects[ 0 ].face ) {

					INTERSECTED = intersects[ 0 ].face;
 					if(action=="mouseOver"){
						intersects[0].face.textje = "wat een gepruts";
						intersects[0].face.color = new THREE.Color(0xf2b640);
						if(intersectObjects){
							// for(var i=0; i<intersectObjects.children.length; i++){
							// 									//objectLayer.children[i].material.opacity=objectLayer.children[i].alphaOrg;
							// 									intersectObjects.children[i].material.opacity=0;
							// 							}

						}
						setMouseOver(INTERSECTED);

					}

				}
					
			}else{
				if ( INTERSECTED != intersects[ 0 ].object ) {

					INTERSECTED = intersects[ 0 ].object;
					if(action=="focus"){
						// var targetFocus=intersects[ 0 ].point;
						// 
						// 					var dist = getDistance(camera.position, projection)-globeRadius;
						// 					distanceTarget = dist-(dist*0.75);
						// 					if(distanceTarget < 1 )distanceTarget=1;
						// 					target=getLatLong(targetFocus, globeRadius, projection);
						// 					target.lng-=1.75;
						// 					target.lat+=0.1;
						INTERSECTED=null;


					}else if(action=="mouseOver"){
						setMouseOver(INTERSECTED);
					}
				}
	
			}	

		} else {
			//if(INTERSECTED)INTERSECTED.visible=false;
			var i=0;
			while(i<scene.children.length){
				if(scene.children[i].name=="mouse_info"){
					scene.remove(scene.children[i]);
					i--;
				}
				i++;
			}
			
			INTERSECTED = null;
			tooltip.hide();

		}
  }

  function setMouseOver(intersected){
		
		var ttText;
		if(intersected.layer=="ptlive"){
			var delay;
			//console.log(scene.children);
			if(intersected.delay==false){
				delay="<br>delay: <span style=color:"+fontBlue+"> on time</span>"

			}else{
				if(intersected.delay<0){
				 	delay="<br>ahead: <span style=color:"+fontBlue+">"+parseInt(Math.abs(intersected.delay/1000))+"</span> sec";	
				}else{
					delay="<br>delay: <span style=color:"+fontBlue+">"+parseInt(intersected.delay/1000)+"</span> sec";
				}
			}

			ttText="line: <span style=color:"+fontBlue+">"+intersected.name+"</span> to : <span style=color:"+fontBlue+"> "+intersected.laststop+"</span>"
			+"<br>next stop: <span style=color:"+fontBlue+"> "+intersected.nextstop+"</span>"
			+"<br>time to next stop: <span style=color:"+fontBlue+"> "+parseInt(intersected.timeleft/1000)+"</span> sec"
			+delay;

			//+"<br>delay: <span style=color:"+fontBlue+"> "+INTERSECTED.delay+"</span>";
			if(intersected.additionalGeo){
				var lineData={geom:intersected.geom};				
				var data=[];
				data.push(lineData);
				var dataLayer={layer:"mouse_info", properties:{dynamic:false, dotSize:0.25, lines:true, shape:false}, geoRepository:{}};
				
				globe.addData(data, dataLayer);

			}
			
			
		}else {

			//ttText=intersected.textje;
			// intersected.material.opacity=0.9;
			intersected.visible=true;
			ttText="<span style=color:"+fontBlue+">Statistics C.B.S.</span><br>";			
			var data = intersected.data.layers.cbs.data;
						
			var count=0;
			var index;
			for(var index in data) {
				if(count%2 == 0){
					ttText+="<span style=color:"+fontBlue+">"+index+"</span> : "+data[index]+"<br>"
				}else{
					ttText+="<span style=color:"+fontBlue+">"+index+"</span> : "+data[index]+" -- "
				}
				count++;

			}
	
		}
		tooltip.show(ttText);
	}

  function onDocumentMouseMove( event ) {

		event.preventDefault();
		//if(!mouseRayActive)return;
		var mouseRay={x:0, y:0}
		mouseRay.x = ( event.clientX / window.innerWidth ) * 2 - 1;
		mouseRay.y = - ( event.clientY / window.innerHeight ) * 2 + 1;
		rayDetectObjects(mouseRay, "mouseOver");

  }

	function onDoubleClick( event ) {
			orbit=false;
			event.preventDefault();
			console.log("double click");
			var mouseRay={x:0, y:0}
			mouseRay.x = ( event.clientX / window.innerWidth ) * 2 - 1;
			mouseRay.y = - ( event.clientY / window.innerHeight ) * 2 + 1;
			rayDetectObjects(mouseRay, "focus");

	  }
 

  toggleLayer = function(target){

	var newLiveLayer=target.layer.search("pt_live");
	if(newLiveLayer>1){
		for(i=0; i<layerStack.length; i++){
		
			var liveLayer=layerStack[i].layer.search("pt_live");
			if(liveLayer>0){
				subsLive.tram=true;
				subsLive.bus=true; 
				subsLive.ferry=true; 
				subsLive.subway=true;
				for(var j=0; j<layerStack[i].subs.length; j++){
					layerStack[i].subs[j].visible=false;
				}
						
				console.log("removing live layer :"+layerStack[i].layer);
				layerStack.splice(i, 1);
				break;
			}
		
		}
	}
	

	for(i=0; i<layerStack.length; i++){
				
		if(target.layer==layerStack[i].layer){
				console.log("removing layer :"+layerStack[i].layer);
				layerStack.splice(i, 1);
				break;	
		}
	
	}
	
	if(target.visible==true){
		layerStack.unshift(target);
		console.log("adding layer :"+layerStack[i].layer);
		
	}

	
	i=0;
	while (i<scene.children.length)
	{
	  	if(scene.children[i].name==target.layer && target.visible==false){
			scene.remove(scene.children[i]);
			i--;
		}
		
		i++;
	 }
	
	

  }


var subsLive={tram:true, bus:true, ferry:true, subway:true};
  toggleSubLayer = function(layer, subLayer, visible){
  var i;

	for(key in poolPtLive){
		if(poolPtLive[key].layer=="ptTrams" && subLayer=="tram"){
			poolPtLive[key].ps.visible=visible;
			subsLive.tram=visible;
		}else if(poolPtLive[key].layer=="ptBuses" && subLayer=="bus"){
			poolPtLive[key].ps.visible==visible;
			subsLive.bus=visible;
		}else if(poolPtLive[key].layer=="ptFerrys" && subLayer=="ferry"){
			poolPtLive[key].ps.visible==visible;
			subsLive.ferry=visible;
		}else if(poolPtLive[key].layer=="ptSubways" && subLayer=="subway"){
			poolPtLive[key].ps.visible==visible;
			subsLive.subway=visible;
		}

	};

	
	// if(subLayer=="lines"){
	// 	 	subLayer=layer+"_lines";
	// 	}else if(subLayer=="stops"){
	// 	 	subLayer=layer+"_dots";
	// 	}
		
	for(i=0; i<scene.children.length; i++){
			if(scene.children[i].name==layer){
				if(subLayer=="lines"){
					if(scene.children[i] instanceof THREE.Line){
						scene.children[i].visible=visible;
					}
				}else if (subLayer=="stops"){
						if(scene.children[i] instanceof THREE.ParticleSystem){
							scene.children[i].visible=visible;
						}
				}


			}
	}

	//console.log("toggle sub layer :"+subLayer+" visible="+visible);
	
  }	

function onMouseDown(event) {
    event.preventDefault();
	globeInited=true;
	orbit=true;
    container.addEventListener('mousemove', onMouseMove, false);
    container.addEventListener('mouseup', onMouseUp, false);
    container.addEventListener('mouseout', onMouseOut, false);

    mouseOnDown.x = - event.clientX;
    mouseOnDown.y = event.clientY;

	var d = getDistance(camera.position, projection);
	var ll=getLatLong(camera.position, d, projection);

    targetOnDown.lat = ll.lat;
    targetOnDown.lng = ll.lng;

    container.style.cursor = 'move';


  }



  function onMouseMove(event) {
		
    mouse.x = - event.clientX;
    mouse.y = event.clientY;
	var d = getDistance(camera.position);
	if(d>100){
		d=distanceInit;
	}

	target.lng = targetOnDown.lng + ((mouse.x - mouseOnDown.x) * (0.2*zoomDamp) );
    target.lat = targetOnDown.lat + ((mouse.y - mouseOnDown.y) * (0.2*zoomDamp) );

    target.lat = target.lat > 89 ? 89 : target.lat;
    target.lat = target.lat < - 89 ? - 89 : target.lat;

  }

  


  function onMouseUp(event) {
	orbit=false;
	var d = getDistance(camera.position, projection);
	var ll=getLatLong(camera.position, d, projection);
	//console.log("mouse up cam lat ="+ll.lat+" - lng="+ll.lng);

	container.removeEventListener('mousemove', onMouseMove, false);
    container.removeEventListener('mouseup', onMouseUp, false);
    container.removeEventListener('mouseout', onMouseOut, false);
    container.style.cursor = 'auto';


  }

  function onMouseOut(event) {
	orbit=false;
    container.removeEventListener('mousemove', onMouseMove, false);
    container.removeEventListener('mouseup', onMouseUp, false);
    container.removeEventListener('mouseout', onMouseOut, false);

  }

  function onMouseWheel(event) {
	event.preventDefault();
	 var evt=window.event || event //equalize event object
	 var delta=evt.detail? evt.detail*(-10) : evt.wheelDelta //check for detail first so Opera uses that instead of wheelDelta

    zoom(delta);
    return false;
  }


  function onDocumentKeyDown(event) {
	//console.log(event.keyCode);	
    switch (event.keyCode) {
		case 80:
		// starting recording
		//var recordingTimer=setInterval(function(){recordData()}, 60000);
		break;
		
		case 84:
			//toggle projection key=t
			//console.log("toggle projection");
			//toggleProjection();
		break;

		case 76:
		 //loadRecordedData();
		break;

		case 32:
		if(log){
			log=false;
		}else{
			log=true;
		}
		break;

	}


  }

  function onWindowResize( event ) {
    console.log('resize');
	w = container.offsetWidth || window.innerWidth;
    h = container.offsetHeight || window.innerHeight;

    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize( window.innerWidth, window.innerHeight );
	stats.domElement.style.left = w-100+'px';
	
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
	
	$("#d3graphs").css({
		'position':"absolute",
		'left':window.innerWidth-720-70+"px",
		'top':window.innerHeight-230+"px",
		'z-index':2000
	});

  }

	
  init();
  
  this.animate = animate;
  this.renderer = renderer;
  this.scene = scene;
  this.camera = camera;
  this.addData=addData; // new data from citysdk
  this.addLoadedData=addLoadedData;	// loaded memory data
  this.addExternalApiData=addExternalApiData;	
  this.focusCity=focusCity;
  this.toggleLayer=toggleLayer;
  this.toggleSubLayer=toggleSubLayer;
  this.toggleProjection=toggleProjection;
  
    
  return this;   

};


