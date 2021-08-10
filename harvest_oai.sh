#!/bin/bash
STATE=`ps ax | grep harvest_oai.php | wc -l`
echo "--------------------------------"
date
if [ "$STATE" == "1" ] ; then
    php -f /var/www/vufind/harvest/harvest_oai.php
else
    echo "harvest_oai.php is already running"
fi
