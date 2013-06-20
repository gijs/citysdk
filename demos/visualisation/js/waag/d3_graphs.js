var d3container;


function initD3(){
	
	d3container=document.getElementById("d3graphs");
	
	$("#d3graphs").css({
		'position':"absolute",
		'left':window.innerWidth-720-70+"px",
		'top':window.innerHeight-230+"px",
		'z-index':2000
	});
	console.log("D3 innited");
}

function setD3Graph(data){
	var margin = {top: 20, right: 40, bottom: 40, left: 20},
	width = 720, height = 180 ;
		
	var parseDate = d3.time.format("%Y-%m-%d").parse;
	var x = d3.time.scale()
	     .range([0, width]);

	var y = d3.scale.linear()
	    .range([height, 0]);

	var xAxis = d3.svg.axis()
	    .scale(x)
	    .orient("bottom");

	var yAxis = d3.svg.axis()
	    .scale(y)
	    .orient("right");

	var line = d3.svg.line()
	    .x(function(d) { return x(d.date); })
	    .y(function(d) { return y(d.deaths_max); });
	
	var svg = d3.select(d3container).append("svg")
	    .attr("width", width + margin.left + margin.right)
	    .attr("height", height + margin.top + margin.bottom)
	  .append("g")
	    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");


	
		console.log("set graph");
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

	  x.domain(d3.extent(data.strike, function(d) { return d.date; }));
	  //y.domain(d3.extent(data.strike, function(d) { return d.deaths_max; }));
	  y.domain([0, d3.max(data.strike, function(d) { return d.deaths_max; })]);
	  svg.append("g")
	      .attr("class", "x axis")
	      .attr("transform", "translate(0," + height + ")")
	      .call(xAxis);

	 svg.append("path")
	     .datum(data.strike)
	     .attr("class", "line")
	     .attr("d", line)
		 .attr("width", 0.1);

	svg.append("g")
	      .attr("class", "y axis")
	      .attr("transform", "translate(" + width + ",0)")
		 .call(yAxis)
	    .append("text")
	      .attr("transform", "rotate(-90)")
	      .attr("y", -16)
	      .attr("dy", ".71em")
		  .style("text-anchor", "end")
	      .text("deaths");

	svg.selectAll(".bar")
		.data(data.strike)
	    .enter().append("rect")
	      .attr("class", "bar")
	      .attr("x", function(d) { return x(d.date); })
		  .attr("width", 0.25)
		  .attr("width", 0.25)
	      .attr("y", function(d) { return y(d.deaths_max); })
	      .attr("height", function(d) { return height - y(d.deaths_max)
		});

	svg.selectAll('.dot')
	  .data(data.strike)
      .enter().append("circle")
      .attr("class", "dot")
      .attr("r", 1.5)
      .attr("cx", function(d) { return x(d.date); })
      .attr("cy", function(d) { return y(d.deaths_max); })
	  .on("mouseover", function(d) { showD3MouseOver(d) })	
	  .on("mouseout", function(d) { tooltip.hide(); })	

	
}

function showD3MouseOver(data){

	var ttText="<span style=color:"+fontBlue+">U.S. Drone Strikes</span><br>";		
	for(var index in data) {
		if(index=="_id" || index=="deaths_min" || index=="deaths_max" || index=="tweet_id" || index=="bureau_id" || index=="bij_link" || index=="lat" || index=="lon" ||index=="articles"){
			// do not list
		}else{
			ttText+="<span style=color:"+fontBlue+">"+index+"</span> : "+data[index]+"<br>"
		}
		
		
		
	}
	
	tooltip.show(ttText);
	
}


