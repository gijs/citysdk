




$(document).ready( function() {
  $.stops = {};
  $.lines = {};
  $.newStops = [];
  $.currentLines = [];
  $.currentLinesMarkup = {};
  $.tzoffset = new Date().getTimezoneOffset() / 60;
  
  $.loadTimer = false;
  $.currentPosition = {
    'latitude': 0,
    'longitude': 0
  }
  
  function distance(pos1,pos2) {
    var fact = Math.PI / 180;
    var lat1 = pos1.latitude  * fact;
    var lat2 = pos2.latitude  * fact;
    var lon1 = pos1.longitude * fact;
    var lon2 = pos2.longitude * fact;
    var R = 6371000;
    var x = (lon2-lon1) * Math.cos((lat1+lat2)/2);
    var y = (lat2-lat1);
    return  Math.round(Math.sqrt(x*x + y*y) * R);
  }
  
  function d_from_stop(stop) {
    return distance($.currentPosition,stop)    
  }
  
  function makeID(s) {
    return s.replace(/\./g,'').replace(/\-/g,'')
  }
  
  
  function processStops() {
    stop = $.newStops.shift()
    while( stop != undefined ) {
      getStopInfo(stop)
      stop = $.newStops.shift()
    }
  }
  
  
  function newLocationFound() {
    loadCitySDKData('ptstops?geom&per_page=17&lat='+$.currentPosition.latitude+'&lon='+$.currentPosition.longitude, function(data) {
      $.newStops = []
      for (var i = 0; i < data.results.length; i++) {
        $.newStops.push(data.results[i])
      }
      $.currentLines = [];
      $.currentLinesMarkup = {};
      $('#linelist').empty();
      processStops()
    })
  }
  
  function loadingMessage(b) {
    if( b ) {
      $.loadTimer = setTimeout(function() {
        $.mobile.loading( 'show', {
        	text: 'getting position...',
        	textVisible: true,
        	theme: 'b',
        	html: ""
        });
      },1000)
    } else {
      if($.loadTimer) {
        clearTimeout($.loadTimer);
        $.loadTimer = false;
        $.mobile.loading( 'hide')
      }
    }
  }
  
  function updatePosition(pos) {
    loadingMessage(false)
    console.info("geo location update.")
    if( distance($.currentPosition, pos.coords) > 50 ) {
      $.currentPosition = pos.coords;
      newLocationFound();
    }
  }
  

  function getTimingForLine(l) {
    
    loadCitySDKData(l.stop.cdk_id + '/select/now?tz=' + $.tzoffset, function(data) {
      $.each(data.results, function(i) {
        id = 'times_' + makeID(data.results[i].cdk_id)
        $(id).empty();
        t = data.results[i].times
        a = ''
        $.each(t, function(i) {
          a += "<li>"
          a += t[i]
          a += "</li>"
        })
        if( $.currentLinesMarkup[id] ) {
          $('#linelist').append($.currentLinesMarkup[id])
          $('#linelist').trigger('create');
          delete $.currentLinesMarkup[id]
          $('#'+id).append(a)
        }
      })
    })

  }
  
  
  function createSummary(l) {
    var a = ""
    line = l.line
    stop = l.stop
    
    if(line.layers.gtfs != undefined) {
      name = line.layers.gtfs.modalities[0] + " " + line.layers.gtfs.data.route_short_name;
      name = name[0].toUpperCase() + name.slice(1);
    } else {
      name = "NS.."
    }
    dest = line.layers.gtfs.data.route_to
    var m_id ='times_' + makeID(line.cdk_id)
    

    a += "<div data-role='collapsible' data-expanded-icon='arrow-u'>" 
    a += "<h3>" + name + "<span class='dir'>dir. " + line.layers.gtfs.data.route_to + "</span></h3>"
    a += line.layers.gtfs.data.agency_id + " " + line.layers.gtfs.modalities[0] + " " + line.layers.gtfs.data.route_short_name
    a += "<table><tr><td class='label'>stop:</td>"
    a += "<td><b>" + stop.name + "</b> (" + d_from_stop(stop) + "m.) </td></tr>"
    a += "<tr><td class='label'>from:</td><td>"
    a += line.layers.gtfs.data.route_from
    a += "</td></tr><tr><td class='label'>to:</td>"
    a += "<td>" + line.layers.gtfs.data.route_to + "</td></tr>"
    a += "</table><table><tr>"
    a += "<td><ul style='font-size:120%' id='" + m_id + "'></ul>"
    a += "</td><td></td></tr></table>"
    a += "</div>"

    $.currentLinesMarkup[m_id]=a;
  }



  function addLineToList(l) {
    if( $.currentLines.indexOf(l.line.cdk_id) == -1 ) {
      $.currentLines.push(l.line.cdk_id)
      if(l.line.layers.gtfs.data.route_to != l.stop.name) {
        createSummary(l);
        getTimingForLine(l) 
      }
    }
  }
  
  function getLineInfo(line, stop) {
    if( $.lines[line.cdk_id] == undefined) {
      $.lines[line.cdk_id] = {
        'stop': stop,
        'line': line,
        'd': d_from_stop(stop)
      }
    } else {
      dist = d_from_stop(stop)
      if( dist < $.lines[line.cdk_id].d ) {
        $.lines[line.cdk_id].d = dist;
        $.lines[line.cdk_id].stop = stop;
      }
    }
    addLineToList($.lines[line.cdk_id])
  }

  function getStopInfo(stop) {
    if( $.stops[stop.cdk_id] == undefined ) {
      stop.latitude = stop.geom.coordinates[1];
      stop.longitude = stop.geom.coordinates[0];
      $.stops[stop.cdk_id] = {}
      loadCitySDKData(stop.cdk_id + '/select/ptlines', function(d) {
        var h = {
          'stop': stop
        }
        h['lines'] = d.results
        $.stops[stop.cdk_id] = h
        for (var i = 0; i < d.results.length; i++) {
          getLineInfo(d.results[i],stop)
        }
      })
    } else {
      lines = $.stops[stop.cdk_id].lines
      for (var i = 0; i < lines.length; i++) {
        getLineInfo(lines[i],stop)
      }
    }
  }

  function loadCitySDKData(path,cb) {
    var cdk_url = 'http://api.citysdk.waag.org/';
    url = cdk_url+path;
    url += (url.split('?')[1] ? '&':'?') + 'geom';
    if( url.indexOf("per_page") == -1 ) {
      url += '&per_page=50';
    }
    $.getJSON(url, function(data) {
      cb(data)
    })
  }

  function getQueryParams(qs) {
      qs = qs.split("+").join(" ");
      var params = {}, tokens, re = /[?&]?([^=]+)=([^&]*)/g;
      while (tokens = re.exec(qs)) {
          params[decodeURIComponent(tokens[1])] = decodeURIComponent(tokens[2]);
      }
      return params;
  }
  
  function locationError(error) {
    loadingMessage(false)
    alert(error.message)
  }

  $.query = getQueryParams(document.location.search);

  if($.query.ll != undefined) {
    // cs: ?ll=52.37817,4.89951
    // nieuwmarkt: ?ll=52.37265,4.90040
    // handweg: ?ll=52.29579,4.84441
    // ijburg: ?ll=52.34792,5.00850
    // plato: ?ll=52.372285,4.816142
    ll = $.query.ll.split(",")
    updatePosition({'coords': {'latitude':ll[0], 'longitude': ll[1]}})
  } else {
    if (navigator.geolocation) {
      console.info("geo location on.")
      loadingMessage(true)
      navigator.geolocation.watchPosition(updatePosition,locationError);
    } else {
      console.info("geo location off.")
      alert("Location services on, please.")
    }
    if (window.DeviceOrientationEvent) {
      window.addEventListener("deviceorientation", function (e) {
        console.info(e.alpha)
        // rotate(360 - e.alpha);
      }, false);
    }
    
  }


});

