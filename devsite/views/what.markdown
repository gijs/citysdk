##What does the CitySDK distribution platform do?
Governments on all levels all over Europe are releasing datasets to the general public. Generally these datasets are downloadable from a special page on a municipal website, often these days there is even a catalogue available such as the ones in [Amsterdam](http://amsterdamopendata.nl) and [Helsinki ](http://www.hri.fi/en/data-search/). This is good news of course, both from a transparency as well as a policy perspective.
However, these data are offered as separate files, that are not linked to each other. To use these data, you have to download the file, look into it's structure, and then link it to other files. E.g. a dataset with parking locations may just contain coordinates but has no link with addresses or streets. Therefore, the parking dataset has to be linked to a map, or an address file to enable its effective use. Because you often need to connect several dataset for a useful application, this is a huge amount of work.

CitySDK links all datasets to Open Street Map and to each other. In that way you can search for an address, coordinate or datapoint and see what connections or data are available in all datasets together.

###Example Amsterdam
<cs.png>
An Example: Amsterdam Central Station is the most important transport hub in our city. Several datasets are available in which this place is referenced. There are of course travel schedules for trains, but also for trams, metro, (regional) buses and ferries. There are datasets for taxi stands, there's weather data, (bike)parking and information on the monumental building on wikipedia, crowd sourced info on Foursquare and many more. Although each of these datasets refer to Amsterdam Central Station, each dataset refers to it in a different way. With a different ID number, slightly different location, coordinates or data format. To get these datasets connected you need a [Rosetta Stone](http://en.wikipedia.org/wiki/Rosetta_Stone) to match them all up.

In our case, this Rosette Stone starts with [Open Street Map](http://openstreetmap.org). OSM is basically a database of all physical objects in the world. Each object represented in OSM is called a 'node'. If you look at this OSM image of Amsterdam Central Station, you see that each railroad track is a node, and so are the routes that the ferries take to cross the water. Buildings, roads, bridges, neighbourhoods, cities can all be a node. 
If we link each datapoint from our datasets to a node in Open Street Map, we can link all datasets together.
![Centraal Station](/img/cs.png)


<hr/>

###Example Manchester
Another example: This is a busstop in Manchester: ![Manch. stop1](/img/stop1.png)
The CitySDK API give this busstop a unique ID, which is part of a unique URI:
![Manch. stop2](/img/stop2.png)
Each datapoint from our datasets that have something to say that about this busstop is than linked to this URI. Via this URI a developer can query directly for departure times from this busstop, ask what the weather is, or report to the city that the busstop has been vandalised and needs repair:
![Manch. stop3](/img/stop3.png)
So when looking via the CitySDK API we can find a myriad of data about our cities:
![Manch.](/img/manchester.png)

<hr/>

###Demo
Via our <a href="map">map viewer</a> you can try the API yourself with some example queries. There also a number of pilot apps on our <a href="apps">Apps page</a>.

###Mapping & Snapping
To lay the connection between datasets and nodes in Open Street Map the CitySDK API has to do a lot of work. Two of the most important processes are mapping and snapping.

Mapping means converting the location listed in the original dataset to the coordinates used in Open Street Map. This should be pretty straitghforward with most datasets. Many times though, the location in the original dataset is ambiguous. In Amsterdam the municipality measures the travel speed on main roads in the city. These data are released as open data. When we mapped the raw data on Open Street Map this is what we saw:
![divv.png](/img/divv1.png)
The space between the left and right lanes is enlarged significantly, presumably to make the direction of travel less ambiguous. This makes it impossible to connect the driving times with the roads as available in OSM. An additional process is needed, which we call snapping. An algorithm looks at dataset and OSM and calculates for which road the travel times are relevant. If you look for this data in CitySDK API you can query for the [actual travel speed](/map#nodes?layer=divv.traffic) on main roads.


