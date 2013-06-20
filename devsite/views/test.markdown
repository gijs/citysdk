# Match API

	POST '/util/match'
	
The Match API enables you to link objects your own data with existing nodes in CitySDK Mobility. The API will match objects on name, location and key-value data and return the `cdk_id` of the CitySDK nodes it finds.

You need a valid CitySDK user account to use the Match API.

Perhaps some use cases will illustrate best how the Match API can be used:

1. __Train stations__: suppose you have data about train stations (e.g. departure times) in a certain country. Most of those stations will be probably already exist in CitySDK on the [OSM base layer](http://api.citysdk.waag.org/admr.nl.nederland/nodes?osm::railway=station). You can read more about how OSM tags train stations on the [OSM wiki](http://wiki.openstreetmap.org/wiki/Tag:railway%3Dstation). The Match API can be used to find those train stations and link them to the corresponding objects in your dataset, based on name, location and meta-data.

2. __Museum opening times__: let's say you keep an updated list of the opening times of all the museus in your home town. Again, probably many of the museums in your dataset will be [readily available in CitySDK](http://api.citysdk.waag.org/admr.uk.gr.manchester/nodes?osm::tourism=museum), since OSM has a dedicated [`museum` tag](http://wiki.openstreetmap.org/wiki/Tag:tourism%3Dmuseum). If you provided your museum dataset in the JSON structure explained in detail below, the Match API will try to find museums that exist in both your dataset and CitySDK. 

3. __Real-time traffic information__: the previous use cases showed how the Match API can match objects from your datasets to single CitySDK nodes. Just finding single nodes will not suffice when you have, for example, traffic jam data for stretches of highways. admr.nl.rotterdam/nodes?osm::highway=motorway

4.  OSM uses the [`highway` tag](http://wiki.openstreetmap.org/wiki/Key:highway) to distinguish different types of roads and highways.
4. routes 
5. graph of the [OSM ways](http://wiki.openstreetmap.org/wiki/Way)
6. [Dijkstra's algorithm](http://en.wikipedia.org/wiki/Dijkstra's_algorithm)



Important: matching is a database-intensive task and requests to the Match API can take some time to return. Requests can time out when you are trying to match too many nodes at once. If time out problems occur, please try to match your data in batches.

## Input

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
    
### Point matching

### Line matching

### Polygon matching

Polygon matching is not yet supported.

## Output

The Match API will of course not always be able to match all the objects in your dataset with an object in CitySDK; sometimes the Match API will find no object at all, and sometimes it will find an incorrect match.

You can use the Bulk API to create missing nodes, but please only proceed with creating new nodes when you're absolutely sure the objects you need do not exist in CitySDK. You should always thouroughly check Match API results, try different matching parameters and try to look for objects manually as well. The linking of different dataset through existing CitySDK/OSM nodes is the main advantage of using the CitySDK API. The Match API can help data owners with this linking, but manual checks and manual linking will be inevitable.

modified nodes array. You can use this array to send to the [Bulk API](api_write.html#bulk).

Debug

id-cdk_id
nodes, routes-cdk_ids