#External webservices interface

This simple api serves as a bridge between external web services and the CitySDK on-demand web service functionality.
The CitySDK on-demand web service interface sends a JSON object (the 'static' layer data) to a web service (in the layer specification). 
The web service should then return a JSON object, either the modified 'static' one or a completely new 'dynamic' one.

Since not many existing web services (out there in the real world) function this way, this api acts as translating middleware.

This implemetation will server as a guidline to building your own 'translators'.



