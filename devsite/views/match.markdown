## Match API

The Match API enables you to link objects your own data with existing nodes in CitySDK Mobility. The API will match objects on name, location and key-value data and return the `cdk_id` of the CitySDK nodes it finds. You need a valid CitySDK user account to use the Match API.

<div class="code">
  <table>
    <tr>
      <td>
        <code>POST /util/match</code>
      </td>
      <td class='desc'>
        Match objects with existing CitySDK nodes.
      </td>
    </tr>
  </table>
</div>	

The following use cases will illustrate why you need the Match API and how it can be used:

1. __Train stations__: suppose you have data about train stations (e.g. departure times) in a certain country. Most of those stations will be probably already exist in CitySDK on the [OSM base layer](http://api.citysdk.waag.org/admr.nl.nederland/nodes?osm::railway=station). You can read more about how OSM tags train stations on the [OSM wiki](http://wiki.openstreetmap.org/wiki/Tag:railway%3Dstation). The Match API can be used to find those train stations and link them to the corresponding objects in your dataset, based on name, location and meta-data.

2. __Museum opening times__: let's say you keep an updated list of the opening times of all the museus in your home town. Again, probably many of the museums in your dataset will be [readily available in CitySDK](http://api.citysdk.waag.org/admr.uk.gr.manchester/nodes?osm::tourism=museum), since OSM has a dedicated [`museum` tag](http://wiki.openstreetmap.org/wiki/Tag:tourism%3Dmuseum). If you provide your museum dataset in the JSON structure explained in detail below, the Match API will try to find museums that exist in both your dataset and CitySDK. 

3. __Real-time traffic information__: the previous use cases showed how the Match API can match objects from your datasets to single CitySDK nodes. Just finding single nodes will not suffice when you have, for example, traffic jam data for stretches of highways. OSM uses the [`highway` tag](http://wiki.openstreetmap.org/wiki/Key:highway) to distinguish different types of roads and highways. The Match API can also find paths through connected [OSM ways](http://wiki.openstreetmap.org/wiki/Way) if they closely match a given linestring.

__Important__: matching is a database-intensive task and requests to the Match API can take some time to return. Requests can time out when you are trying to match too many nodes at once. If time-out problems occur, please try to match your data in batches.

### Input

The Match API expects JSON in the following form:

  	{
  	  "match": {
  	    "params": {
  	      "radius": 350,
  	      "debug": true,
  	      "srid": 4326,
  	      "geometry_type": "point",
  	      "layers": {
  	        "osm": {
  	          "railway": "station"
  	        }
  	      }
  	    },
        "known": {
          "ASD": "n46419880"
        }
  	  },
  	  "nodes": [
  	    {
          "id": "ASD",
          "name": "Amsterdam Centraal",
          "modalities": ["rail"],
          "geom" : {
          	"type": "Point",
            "coordinates" : [
              4.9002776,
              52.378887
            ]
          },
          "data" : {
          	"naam_lang": "Amsterdam Centraal",   
            "code": "ASD"
          }
        }
  	  ]
  	}
    
#### Match parameters    

- `radius`: the distance from the node geometry in meters within which the Match API should search. 
- `srid`: defines the SRID of the GeoJSON geometries for all nodes to be matched.
- `modalities`: defines the node-level modalitites. Really only relevant for route nodes.
- `geometry_type`: sets the geometry type of the nodes in the `nodes` array. Must be either `point` or `line`.
- `layers`: specifies, per layer, filters on key/value pairs of acceptable nodes. Matched nodes must satisfy any of the given filters, not all.
- `debug`: the Match API returns useful debug information when set to `true`.

#### Known matches

You can turn off matching for certain nodes if you've already (manually) linked your data to existing CitySDK nodes. This can be useful if you want to (partially) update your dataset but want to keep existing links, or if you want to manually set the `cdk_id` for objects you know the Match API returns the wrong results.

The `known` object is a key/value hash, where keys are ids from your data and the values are __existing__ `cdk_id`s. 

### Matching
    
#### Point matching

    {"geometry_type": "point"}

The Match API will search all applicable nodes within `radius` meters of the node geometry and sort them by name similarity and distance, using [amatch](https://github.com/flori/amatch)'s [pair distance metric](http://www.catalysoft.com/articles/StrikeAMatch.html) and PostGIS's [ST_Distance](http://postgis.refractions.net/docs/ST_Distance.html) function.

#### Line matching

    {"geometry_type": "line"}
    
The Match API can do more than just find matches between point geometries; the Match API can also try to match given linestrings to the OSM node/way graph and return sets of CitySDK nodes from which consequently CitySDK routes can be created. OSM (and thus CitySDK) contains networks of connected [nodes](http://wiki.openstreetmap.org/wiki/Node) and [ways](http://wiki.openstreetmap.org/wiki/Way), defined by different OSM tags. You can use OSM's [`highway` tag](http://wiki.openstreetmap.org/wiki/Key:highway) to match a linestring to an existing stretch of road, highway or bike path, but you can the same for [rail networks](http://wiki.openstreetmap.org/wiki/Key:railway) or [waterways](http://wiki.openstreetmap.org/wiki/Key:waterway).

More information about the OSM graph can be found here:
 
- http://wiki.openstreetmap.org/wiki/Routing
- http://wiki.openstreetmap.org/wiki/OSM_tags_for_routing
- https://www.gaia-gis.it/fossil/spatialite-tools/wiki?name=graphs-intro

For example, let's consider a [GeoJSON file](match/example.geojson) which contains a linestring annotated with real-time traffic speed in Amsterdam. When you can view this file on a map by [converting it to KML](match/example.kml) and opening it (i.e. in Google Earth), you can see that the linestring lies close lies close to a road called the 'Muiderstraatweg'. This Muiderstraatweg is available both in [OpenStreetMap](http://www.openstreetmap.org/?lat=52.33593&lon=4.96792&zoom=15&layers=M) and in [CitySDK](http://dev.citysdk.waag.org/map.html#admr.nl.diemen/nodes?name=muiderstraatweg).
  
When set to line matching, the Match API will try to find a connected network close to any given linestring, using the provided OSM key/tag filters. Through this network, the Match API will use [Dijkstra's algorithm](http://en.wikipedia.org/wiki/Dijkstra's_algorithm) to find a path in the OSM network starting close to the start of the linestring and ending close to the end of the linestring.

The following Match API input is a fragment from the `divv.traffic` layer importer data:

    {
      "match": {
        "params": {
          "radius": 125,
          "srid": 4326,
          "debug": true,
          "geometry_type": "line",
          "ignore_oneway": false,
          "layers": {
            "osm": {
              "highway": [  
                "unclassified", "road",
                "motorway", "motorway_link",
                "trunk", "trunk_link",
                "primary", "primary_link",
                "secondary", "secondary_link",
                "tertiary", "tertiary_link"
              ]
            }
          }
        }
      },
      "nodes": [
        {
          "id": "TrajectSensor_Route130_R",
          "data": {
              "location": "TrajectSensor_Route117_R",
              "velocity": 48,
              "length": 700
          },
          "geom": {"type":"LineString","coordinates":[[4.95344,52.33958],[4.95532,52.33916],[4.95684,52.33883],[4.95897,52.33840],[4.95982,52.33836],[4.96037,52.33825],[4.96195,52.33789],[4.96353,52.33755],[4.96622,52.33714],[4.96797,52.33662],[4.97038,52.33593],[4.97322,52.33510],[4.97585,52.33431],[4.97628,52.33422],[4.97675,52.33415],[4.97682,52.33411],[4.97704,52.33403],[4.97715,52.333886],[4.97741,52.333751],[4.97793,52.33356],[4.97960,52.33328],[4.98043,52.33315],[4.98169,52.33307],[4.98345,52.33302],[4.98399,52.33313],[4.98430,52.33330]]}
        }
      ]
    }
    
You can set the `ignore_oneway` to `true` if you ant the line matcher to ignore the OSM [oneway tag](http://wiki.openstreetmap.org/wiki/Key:oneway).

The Match API will return a set of `cdk_id`s in the correct order, which is used to create a new CitySDK route:

- [Route with `divv.traffic` data](http://api.citysdk.waag.org/divv.traffic.trajectsensor_route130_r?layer=divv.traffic&geom)
- [Nodes this route consists of](http://api.citysdk.waag.org/divv.traffic.trajectsensor_route130_r/select/nodes)

#### Polygon matching

Polygon matching is not yet supported.

### Output

__Important__: the Match API will of course not always be able to match all the objects in your dataset with an object in CitySDK; sometimes the Match API will find no object at all, and sometimes it will find an incorrect match.

You can use the Bulk API to create missing nodes, but please only proceed with creating new nodes when you're absolutely sure the objects you need do not exist in CitySDK. You should always thouroughly check Match API results, try different matching parameters and try to look for objects manually as well. The linking of different dataset through existing CitySDK/OSM nodes is the main advantage of using the CitySDK API. The Match API can help data owners with this linking, but manual checks and manual linking will be inevitable. You can use the known matches object to manually turn off matching for certain nodes.

The Match API returns a modified version of the submitted `nodes` array which you can send directly to the [Bulk API](write.html#bulk).