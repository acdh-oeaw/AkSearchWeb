#!/bin/bash
STATE=`ps ax | grep harvest_deguyter.php | wc -l`
echo "--------------------------------"
date
if [ "$STATE" == "1" ] ; then
    php -f /var/www/vufind/harvest/harvest_deguyter.php
else
    echo "harvest_deguyter.php is already running"
fi
