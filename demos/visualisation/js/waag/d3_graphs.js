var d3container;
var graphWidth=960;
var margin = {top: 10, right: 40, bottom: 100, left: 10},
    margin2 = {top: 200, right: 40, bottom: 20, left: 10},
    d3Width = 960 - margin.left - margin.right,
    d3Height = 300 - margin.top - margin.bottom,
    d3Height2 = 280 - margin2.top - margin2.bottom;
var parseDate, formatPercent;

function initD3(){
	
	d3container=document.getElementById("d3graphs");
	
	$("#d3graphs").css({
		'position':"absolute",
		'left':window.innerWidth-graphWidth-20+"px",
		'top':window.innerHeight-310+"px",
		'z-index':2000
	});
	
	parseDate = d3.time.format("%Y-%m-%d").parse;
	formatPercent = d3.format(".0%");
	
	console.log("D3 innited");
}
 

function setD3GraphDronesBrushed(data){
			
	var x = d3.time.scale().range([0, d3Width]),
	    x2 = d3.time.scale().range([0, d3Width]),
	    y = d3.scale.linear().range([d3Height, 0]),
	    y2 = d3.scale.linear().range([d3Height2, 0]);

	var xAxis = d3.svg.axis().scale(x).orient("bottom"),
	    xAxis2 = d3.svg.axis().scale(x2).orient("bottom"),
	    yAxis = d3.svg.axis().scale(y).orient("left").orient("right");

	var brush = d3.svg.brush()
	    .x(x2)
	    .on("brush", brushed);

	var areaFocus = d3.svg.area()
		    .interpolate("monotone")
		    .x(function(d) { return x(d.date); })
		    .y1(function(d) { return y(d.deaths_max); })

		
	var areaBrush = d3.svg.area()
		.interpolate("monotone")
	    .x(function(d) { return x2(d.date); })
	    .y0(d3Height2)
	    .y1(function(d) { return y2(d.deaths_max); });
		
	
	
	var lineFocus = d3.svg.line()
		.interpolate("monotone") // makes a spline
		.x(function(d) { return x(d.date); })
		.y(function(d) { return y(d.deaths_max); });


	var svg = d3.select(d3container).append("svg")
	    .attr("width", d3Width + margin.left + margin.right)
	    .attr("height", d3Height + margin.top + margin.bottom);

	svg.append("defs").append("clipPath")
	    .attr("id", "clip")
	  .append("rect")
	    .attr("width", d3Width)
	    .attr("height", d3Height);

	var focus = svg.append("g")
	    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

	var context = svg.append("g")
	    .attr("transform", "translate(" + margin2.left + "," + margin2.top + ")");


	data.strike.forEach(function(d) {
	    	var dateSliced = d.date.slice(0, 10);	
			var dateFormatted=parseDate(dateSliced);
		    d.date = dateFormatted;	

			var value = d.deaths_max.match(/\d+/g);
			if (value == null) {
			    d.deaths_max=0;
			}

		d.deaths_max = +d.deaths_max;
	  });

	  x.domain(d3.extent(data.strike.map(function(d) { return d.date; })));
	  y.domain([0, d3.max(data.strike.map(function(d) { return d.deaths_max; }))]);
      	  
	  x2.domain(x.domain());
	  y2.domain(y.domain());

	// draw focus area
	  // focus.append("path")
	  // 	  	  	      .datum(data.strike)
	  // 	  	  	      .attr("clip-path", "url(#clip)")
	  // 	  	  	      .attr("d", areaFocus);
	
	  focus.append("path")
		   .datum(data.strike)
		   .attr("class", "line")
		   .attr("d", lineFocus)
		   .attr("d3Width", 0.25);
		  
	
	  focus.selectAll(".bar")
		.data(data.strike)
	    .enter().append("rect")
	      .attr("class", "bar")
	      .attr("x", function(d) { return x(d.date); })
		  .attr("width", 0.25)
	      .attr("y", function(d) { return y(d.deaths_max); })
	      .attr("height", function(d) { return d3Height - y(d.deaths_max)
		});	
		
		focus.selectAll('.dotRed')
		  .data(data.strike)
	      .enter().append("circle")
	      .attr("class", "dotRed")
	      .attr("r", 1.5)
	      .attr("cx", function(d) { return x(d.date); })
	      .attr("cy", function(d) { return y(d.deaths_max); })
		  .on("mouseover", function(d) { showD3MouseOver(d) })
		  .on("mouseout", function(d) { tooltip.hide(); })	
	
	  focus.append("g")
	      .attr("class", "x axis")
	      .attr("transform", "translate(0," + d3Height + ")")
	      .call(xAxis);

	  focus.append("g")
	      .attr("class", "y axis")
	      .attr("transform", "translate(" + d3Width + ",0)")
		 .call(yAxis)
	    .append("text")
	      .attr("transform", "rotate(-90)")
	      .attr("y", -16)
	      .attr("dy", "1em")
		  .style("text-anchor", "end")
	      .text("DEATHS");
	
	// draw brush area
	  // context.append("path")
	  // 	  	  	      .datum(data.strike)
	  // 	  	  	      .attr("d", areaBrush);
	  
	  context.selectAll('.dotRed')
		  .data(data.strike)
	      .enter().append("circle")
	      .attr("class", "dotRed")
	      .attr("r", 0.5)
	      .attr("cx", function(d) { return x(d.date); })
	      .attr("cy", function(d) { return y2(d.deaths_max); })

	  context.append("g")
	      .attr("class", "x axis")
	      .attr("transform", "translate(0," + d3Height2 + ")")
	      .call(xAxis2);

	  context.append("g")
	      .attr("class", "x brush")
	      .call(brush)
	    .selectAll("rect")
	      .attr("y", -6)
	      .attr("height", d3Height2 + 7);
	
		function brushed() {
		  x.domain(brush.empty() ? x2.domain() : brush.extent());
		
		  focus.select("path").attr("d", lineFocus);
		  //focus.select("path").attr("d", areaFocus);
		
		  focus.selectAll('.dotRed')
			  .data(data.strike)
		      .attr("cx", function(d) { return x(d.date); })
		  focus.selectAll(".bar")
       		.data(data.strike)
	      	.attr("x", function(d) { return x(d.date); })
		
		  focus.select(".x.axis").call(xAxis);
		}
	
}


function showD3MouseOver(data){

	var ttText="<strong><span style=color:"+fontBlue+">U.S. Drone Strikes</span></strong><br>";		
	for(var index in data) {
		if(index=="_id" || index=="deaths_min" || index=="deaths_max" || index=="tweet_id" || index=="bureau_id" || index=="bij_link" || index=="lat" || index=="lon" || index=="articles" || index=="names"){
			// do not list
		}else{
			ttText+="<span style=color:"+fontBlue+">"+index+"</span> : "+data[index]+"<br>"
		}
		
		
		
	}
	
	tooltip.show(ttText);
	
}

function removeGraph(id){

	//var svg=d3container.getElementById("drones");
	var graphs=d3.select("svg");
	
	// while (i<graphs.length)
	// 	{		
	// 		if(graphs[i].id=="drones"){
	// 			scene.remove(scene.children[i]);
	// 			i--;
	// 		}
	// 		i++;
	// 	}
	
	//d3.select("svg").remove();
	
}


