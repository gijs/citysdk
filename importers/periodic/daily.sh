#!/bin/bash

log=/usr/local/nginx/logs/citysdk.daily.log
touch "$log"
date >> "$log"

. /usr/local/rvm/scripts/rvm
ruby=`which ruby`

for i in /var/www/citysdk/shared/periodic/daily/*.rb
do
    if test -f "$i" 
    then
      $ruby $i >> "$log"
    fi
done

rm /var/www/csdk_cms/shared/filetmp/*


