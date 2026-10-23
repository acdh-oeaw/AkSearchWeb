#!/bin/bash
echo "#################################"
echo "# Running $0 on `date`"
SET=$1
SET=${SET:=alma}
SOLR_USER=${SOLR_USER:=8983}
STATE=`ps ax | grep harvest_oai.php | wc -l`
if [ "$STATE" == "1" ] ; then
    php -f /var/www/vufind/harvest/harvest_oai.php $SET
    chown $SOLR_USER /var/www/local/harvest/$SET/*xml /var/www/local/harvest/$SET/*txt
    echo "# Harvesting ended on `date`"
else
    echo "# Skipping - harvest_oai.php is already running"
fi
