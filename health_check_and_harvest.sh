#!/bin/bash
curl http://127.0.0.1/vufind/ > /dev/null 2>&1
RET=$?

SOLR_USER=${SOLR_USER:=8983}

HARVEST_PERIOD=360
chown $SOLR_USER /var/www/local/harvest/alma
if [ "`find /var/www/local/harvest/alma -maxdepth 1 -name last_harvest.txt -mmin -$HARVEST_PERIOD`" == "" ] ; then
    touch /var/www/local/harvest/alma/last_harvest.txt
    nohup /var/www/vufind/harvest/harvest_oai.sh >> /var/www/vufind/harvest/harvest_oai.log 2>&1
fi

HARVEST_PERIOD=1440
chown $SOLR_USER /var/www/local/harvest/degruyter
if [ "`find /var/www/local/harvest -maxdepth 1 -name harvest_degruyter.json -mmin -$HARVEST_PERIOD`" == "" ] ; then
    touch /var/www/local/harvest/harvest_degruyter.json
    nohup /var/www/vufind/harvest/harvest_degruyter.sh /var/www/local/harvest/harvest_degruyter.json $DEGRUYTER_PSWD >> /var/www/vufind/harvest/harvest_degruyter.log 2>&1
fi

exit $RET
