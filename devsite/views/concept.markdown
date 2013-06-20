## CitySDK Mobility API

The CitySDK Mobility API, developed by [Waag Society](http://waag.org/) is a layer-based data distribution and service kit. Part of CitySDK, a European project in which eight cities (Manchester, Rome, Lamia, Amsterdam, Helsinki, Barcelona, Lisbon and Istanbul) and more than 20 organisations collaborate, the CitySDK Mobility API enables easy development and distribution of digital services across different cities. The API is a powerful tool that helps governments and officials alike.

## Open data





Waarom heeft Waag de CitySDK API ontwikkeld? Overheden spannen zich sinds enige jaren in om verzamelde informatie en data beschikbaar te maken voor bredere toepassing. Van stadsdeel tot rijksoverheid en de Europese Unie: elk produceert een enorme diversiteit aan data. De plantsoenendienst heeft gegevens over alle Iepen in Amsterdam, onderwijsinspectie en gemeente hebben gegevens over prestaties van scholen, en DIVV meet de doorstroomtijden op de hoofdwegen van Amsterdam. Al deze gremia verzamelen data met hun eigen doelen en middelen, van hun eigen specifiek haarvat van de samenleving.

Het resultaat is dat in heel Europa op duizenden gemeentelijke websites grote lijsten met beschikbare datasets verschijnen. Een enorme stap, vooral ook uit democratisch en ambtelijk perspectief. Maar voor wie aan de slag wil met deze datasets stapelen de problemen zich op. Verschillende bestandsformaten, verversingstermijnen (eens per week of eens per 3 jaar?), data eigenaren die hun dataset zonder aankondiging verplaatsen (naar een 'betere' website) en iedereen meet en registreert weer op zijn geheel eigen manier. 


### Example: DIVV


Een voorbeeld. De gemeente Amsterdam meet met camera's wat de snelheid is van het verkeer op de hoofdwegen in de stad. Deze data worden door de DIVV intern gebruikt in de verkeerscentrale en voor onderzoek en sinds het najaar zijn deze gegevens beschikbaar als Open Data. Logisch zou zijn als je van een hoofdweg waar je bent of waar je naar toe gaat kunt opvragen wat daar de huidige snelheid is van het verkeer. Dan weet je of het druk is, er een file staat of dat je kan doorrijden. Maar toen onze ontwikkelaars de doorstromingsdata op een kaart van Amsterdam legden bleek dat niet mogelijk. 

Op de afbeelding is dat te zien: de data van DIVV (blauw) zijn op de kaart van Amsterdam geprojecteerd. Het valt op dat de linker en rechter rijstrook door DIVV uit elkaar getrokken zijn, wellicht om de rijstroken in verschillende richting visueel goed te kunnen onderscheiden. Praktisch betekent het dat het niet mogelijk is op te vragen wat de snelheid van het verkeer in noordelijke richting in de IJtunnel is - waardoor de toepasbaarheid van de data flink afneemt.

[DIVV](http://www.amsterdam.nl/gemeente/organisatie-diensten/ivv/)

[open data portal](http://www.amsterdam.nl/parkeren-verkeer/open-data/overzicht/)

![DIVV](concept/divv.portal.png)

### Datasets

1.
#### Parking rates
dasdas

2.
#### Parking garages
Het is dus supermooi allemaal

3.
#### Public transportation
dsdsd

4.
#### Electric vehicle charging stations
adasda
ook realtime

5.
#### Traffic flow
dsadasd


## Referenceable objects and linking datasets

All of the datasets above contain data about real-world objects, e.g. parking garages, roads, public transport stops and regions with parking rates. And some of the datasets use unique identifiers which make it possible to 
for each objects

identify those objects with a unique identifier

Most - but not all -
Most of the datasets above




http://5stardata.info/


## OpenStreetMap

CitySDK uses objects from the [OpenStreetMap](http://www.openstreetmap.org/) database as a geospatial base layer, and enables data owners and API users to link datasets to 

each other via the OSM layer.

mobility data 
such as roads, railways, bus stations 
exist as [separate objects](http://wiki.openstreetmap.org/wiki/Elements) in the OpenStreetMap database identifiable with a unique ID.



For example: the Waag building on the Nieuwmarkt in Amsterdam [exists in OSM](http://www.openstreetmap.org/browse/way/57857390); and thus [in CitySDK](http://api.citysdk.waag.org/w57857390?layer=osm).

If you want to explore OpenStreetMap, you can use the "Browse Map Data" option in the layer selector on the [OSM homepage](http://www.openstreetmap.org/) or use on of the many available OSM editors like [Potlatch](http://www.openstreetmap.org/edit?editor=potlatch2), [JOSM](http://josm.openstreetmap.de/) or [iD](http://ideditor.com/).



OSM nodes, ways and relations are acccesible using CitySDK. The `cdk_id` of OSM objects in CitySDK are generated as follows:

| OpenStreetMap | `cdk_id`            | Example
| :------------ |:--------------------|:-------
| Node          | `'n' + node_id`     | Amsterdam Centraal: [OSM](http://www.openstreetmap.org/browse/node/46419880), [CitySDK](http://api.citysdk.waag.org/n46419880).
| Way           | `'w' + way_id`      | Dijksgracht: [OSM](http://www.openstreetmap.org/browse/way/7046048), [CitySDK](http://api.citysdk.waag.org/w7046048).
| Relation      | `'r' + relation_id` | Stedenroute: [OSM](http://www.openstreetmap.org/browse/relation/2816), [CitySDK](http://api.citysdk.waag.org/r2816).

## Nodes, data and layers

## Routes

In de door Waag Society gebouwde API is dit opgelost. De API maakt de versnipperde datasets eenduidig, gestandaardiseerd en op een centrale manier beschikbaar. Ontwikkelaar Bert Spaan heeft bijvoorbeeld een algoritme geschreven dat de snelheden van DIVV koppelt aan wegen en rijstroken. Nog een voordeel van de API is dat je alleen die data krijgt die je opvraagt. Er is geen druk dataverkeer nodig om eerst het hele doorstromingsbestand van Amsterdam te downloaden, je vraagt de snelheid van de wegen op die voor jouw route van belang zijn. In de CitySDK API is nog meer data aanwezig die op je route van belang kan zijn, bijvoorbeeld of het regent - je wil immers niet zozeer weten of het (ergens) in Amsterdam regent, maar of dat voor jouw route het geval is. 


Another core concept of the CitySDK Mobility API is a __route__. A route is defined as an array of nodes, which makes it possible to define abstract routes as well as very detailed ones.

![Routes](concept/routes.png)














