###Importers

These importers are provided as examples. Only the GTFS importer will run elsewhere, the rest are specific to the Amsterdam endpoint implementation.

There's two classes of importer examples available.

* Importers developed before the write part of the API was implemented, directly accessing the database. (admr, rain, gtfs)
* Those which use the api for importing (divv, ns, bridges, parking).

Needless to say, when developing new importers you should follow the second route.

Importers are mosly quite specific to the geographic location and specifics of particular datasets.
There are two layers of data that should really be provided by every endpoint implementation:

1. admr, the 'authorative' administrative regions layer
2. gtfs, general transit feed spec; the public transport layer

ad 1.
How the importer works for the admin regions depends greatly on the format that the data is available at. In the Dutch and Finnish cases that we've imported so far, it was SHAPE and GML respectively.
We've found the easiest route is usually to dump the data in a dedicated database, copy it into citysdk from there, then delete the temporary database.. Either this, or use CSV as an intermediary format.
With the write api now available, generating the JSON import format (see api dev spec) is probably the best choice..

ad 2.
The gtfs importer is generic, should work for any gtfs directory, although not all variants of optional paramaters have been tested.
In order to avoid name colitions when importing multiple gtfs feeds, you can specify a prefix (-p) when importing:
  ruby import.rb -p gbmc. ~/gtfs/manchester
Importing always adds to the database, then does a cleanup of outdated information. 
In simple situations where you have only one feed in the endpoint, it is faster to run the 'clear' script, and then import the new feed version, as this will also clean up stops and routes that no longer exist.



* The GTFS kv8daemon is specific to the OpenOV way of making real-time data availble, of no use outside the Netherlands.
* The DIVV daemon (divv/traffic) is more useful as it shows one way to incorporate real-time data that is made available as a file download that is very frequently updated.







