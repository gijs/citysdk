#!/bin/bash

log=/usr/local/nginx/logs/citysdk.weekly.log
touch "$log"
date >> "$log"

. /usr/local/rvm/scripts/rvm
ruby=`which ruby`

for i in /var/www/citysdk/shared/periodic/weekly/*.rb
do
    if test -f "$i" 
    then
      $ruby $i >> "$log"
    fi
done

cd ../importers/gtfs && $ruby update_gtfs.rb >> "$log"