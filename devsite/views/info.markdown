##Information

CitySDK project site:<br />http://www.citysdk.eu/

CitySDK Mobility API endpoint:<br />http://api.citysdk.waag.org/

Visualisation of CitySDK Mobility data:<br />http://dev.citysdk.waag.org/visualisation/

Most important data sources available through the API, at this moment: 

- General base layer of information and geography ([OpenStreetMap](http://www.openstreetmap.org/)).
- Public transport, schedules and real-time ([openOV](http://www.openov.nl/)) 
- Amsterdam infrastructure and transportation data ([DIVV](http://www.amsterdam.nl/parkeren-verkeer/open-data/overzicht/))
- Further data contributors available through the [`/layers` API](http://api.citysdk.waag.org/layers) or in the [CMS](https://cms.citysdk.waag.org/).

##Examples

- [Statistical data of all neighbourhoods in Zwolle](http://api.citysdk.waag.org/admr.nl.zwolle/regions?admr::admn_level=4&layer=cbs&per_page=50)
- [Rain forecast per neighbourhood in Groningen](http://api.citysdk.waag.org/admr.nl.groningen/regions?admr::admn_level=4&layer=rain)
- [All towns in the Netherlands](http://api.citysdk.waag.org/admr.nl.nederland/nodes?admr::admn_level=3&per_page=500)
- [Museums in Utrecht](http://api.citysdk.waag.org/admr.nl.utrecht/nodes?osm::tourism=museum&per_page=50)
- [Number of inhabitants of Utrecht](http://api.citysdk.waag.org/admr.nl.utrecht/cbs/aant_inw)
- [Find stops in Amsterdam named 'Leidseplein'](http://api.citysdk.waag.org/admr.nl.amsterdam/ptstops?name=Leidseplein)
- [Find lines that stop at one of these](http://api.citysdk.waag.org/gtfs.stop.060671/select/ptlines)
- [Find times for next hour at this stop](http://api.citysdk.waag.org/gtfs.stop.060671/select/now)
- [Find the adminstrative region hierarchy up from the Olympic Stadium in Amsterdam](http://api.citysdk.waag.org/n798432345/select/regions)
- [Real-time traffic flow on main roads in Amsterdam](http://api.citysdk.waag.org/nodes?layer=divv.traffic)
- [LF2 bicycle route](http://api.citysdk.waag.org/r2816)
- [Religion in Rome](http://api.citysdk.waag.org/admr.it.roma/nodes?osm::religion)
- [Routes containing specific set of nodes](http://api.citysdk.waag.org/routes?contains=n726817991,n726817955,n726816865)
- [Tram stops on Utrecht-IJsselstein tram route](http://api.citysdk.waag.org/r326516/select/nodes?osm::railway=tram_stop|halt&data_op=or)
