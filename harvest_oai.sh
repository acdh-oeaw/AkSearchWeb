#!/bin/bash
STATE=`ps ax | grep harvest_oai.php | wc -l`
echo "---------------------------------"
SET=$1
date
if [ "$STATE" == "1" ] ; then
    php -f /var/www/vufind/harvest/harvest_oai.php $SET
else
    echo "harvest_oai.php is already running"
fi