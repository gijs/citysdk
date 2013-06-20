#Installing The CitySDK Mobility API


###System requirements

The API is a **Ruby/Sinatra** app, running off **PostgresQL/Postgis**, served through **Nginx**.

We require postgres 9.2 or higher in order to support some extended data types.
Ruby should be version 1.9.2 or higher, we're running Nginx 1.2.6 and Phusion Passenger > 3.0.

Server hardware needs are dictated by expected use, and amount of data hosted or linked. Enough memory is very important.


###Components

The full API implementation currently consists of:

* the api proper
* one or more daemons to aquire realtime data
* memcached for caching of realtime data
* services endpoint to provide and interface to on-demand external web services
* a cms for layer and data management
* the developer site, with documentation, map and visualisation


###server basic setup

We've installed on Ubuntu 12.04 LTS so far.
Other distros should work without much modification. 

#### install postgresql >= 9.2
  
  Use your package manager; in case 9.2 is not yet available, [this](http://anonscm.debian.org/loggerhead/pkg-postgresql/postgresql-common/trunk/download/head:/apt.postgresql.org.s-20130224224205-px3qyst90b3xp8zj-1/apt.postgresql.org.sh) script will help (for ubuntu).
    

#### install postgis:

  This needs to be installed from source, follow instructions [here](http://trac.osgeo.org/postgis/wiki/UsersWikiPostGIS20Ubuntu1204src).

#### install postgres extensions:
  apt-get install postgresql-contrib


####install osm2pgsql:
  
  At the moment of writing, the standard osm2pgsql available through apt will expect postgres 9.1 and doesn't play nice with 9.2. 
  Therefore, we need to build it from source. This is what works for us:

    sudo apt-get install build-essential libxml2-dev libgeos++-dev libpq-dev libbz2-dev proj libtool automake
    sudo apt-get install libprotobuf-c0-dev protobuf-c-compiler
    cd
    git clone https://github.com/openstreetmap/osm2pgsql.git
    cd osm2pgsql && ./autogen.sh && ./configure
    sed -i 's/-g -O2/-O2 -march=native -fomit-frame-pointer/' Makefile
    make && sudo make install
    ln -s /usr/share/osm2pgsql/default.style /usr/share/default.style
  
  
####install ruby, passenger & nginx:
    sudo -s
    curl -L https://get.rvm.io | bash -s stable --rails
    source /usr/local/rvm/scripts/rvm
    gem install passenger
    cd `passenger-config --root`
    ./bin/passenger-install-nginx-module  (use /usr/local/nginx when asked where to install)

####install memcached:

    apt-get install memcached

    You may want to increase the amount allocated in /etc/memcached.conf


###API Installation Procedure

Once you have the server configured, first order of busniness is to create the 'citysdk' database, and fill the OpenStreetMap layer.
Create database 'citysdk'.
In this database, execute 'create extension postgis; create extension hstore;' 

OSM planet files are downloadable from several locations; [http://download.geofabrik.de/](http://download.geofabrik.de/) is an excellent source.

Now, make sure you have the 'server' part of the download installed on your server machine. We use the directory structure as per Capistrano, which looks like this:

* /var/www/citysdk
* /var/www/citysdk/shared
* /var/www/citysdk/releases
* /var/www/citysdk/current (symlink to latest release)


The /shared directory has some more entries than the default:

* /shared/daemons   -- we run some data importer daemons from here
* /shared/periodic  -- periodically run importer/updater scripts 
* /shared/importers -- all 'other' importers (gtfs)


From now, we'll assume you're working in the 'current' directory (the contents of which should be that of the api/server directory in the download)

Change 'example.database.json' into 'database.json' and make sure the contents reflect your configuration.

To set up the admin user, edit db/migrations/002_insert_constants.rb and at the bottom, change the line:     
    
    self[:owners].insert(:id => 0, :name => 'CitySDK', :email => 'citysdk@waag.org')

to replect your situation, the email address will be needed to add users, layers and data (through the CMS, or using the API).

To seed the database (more information is available as comments in the various shell files):

* cd db
* ./import_osm.sh (after correcting the file name to import, and db credentials)
* ruby ./run_migrations.rb

These commands will take considerable time; hours, most likely, so be patient.

After the migrations have run, you'll need to add a password to the admin account: 

      cd current
      racksh
      o = Owner[0]
      o.createPW('<passwd>')
      <ctrl>-d
      

Importers and daemons won't be directly usable, except for the GTFS importer, but are included to help you get started on your own versions.

Included is our nginx configuration, other servers will work, of course, but nginx is fast and easy to configure. 

The cms, services and dev web apps are simple to deploy, they do not depend on databases of their own..

See the readme's in the respective directories for details.




