#!/bin/bash
STATE=`ps ax | grep harvest_degruyter.php | wc -l`
echo "--------------------------------"
date
if [ "$STATE" == "1" ] ; then
    php -f /var/www/vufind/harvest/harvest_degruyter.php $1 $2
else
    echo "harvest_degruyter.php is already running"
fi
