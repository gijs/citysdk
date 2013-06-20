#!/bin/bash

log=/usr/local/nginx/logs/citysdk.monthly.log
touch "$log"
date >> "$log"

. /usr/local/rvm/scripts/rvm
ruby=`which ruby`

for i in /var/www/citysdk/shared/periodic/monthly/*.rb
do
    if test -f "$i" 
    then
      $ruby $i >> "$log"
    fi
done
