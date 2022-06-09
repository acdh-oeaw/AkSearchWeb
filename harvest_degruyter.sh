#!/bin/bash
echo "#################################"
echo "# Running $0 on `date`"
SOLR_USER=${SOLR_USER:=8983}
STATE=`ps ax | grep harvest_degruyter.php | wc -l`
if [ "$STATE" == "1" ] ; then
    php -f /var/www/vufind/harvest/harvest_degruyter.php $1 $2
    chown $SOLR_USER /var/www/local/harvest/degruyter/*xml /var/www/local/harvest/degruyter/lastDate
    echo "# Harvesting ended on `date`"
else
    echo "# Skipping - harvest_degruyter.php is already running"
fi
