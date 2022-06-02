#!/bin/bash
curl http://127.0.0.1/vufind/ > /dev/null 2>&1
RET=$?

HARVEST_PERIOD=360
if [ "`find /var/www/local/harvest/alma/last_harvest.tx -maxdepth 0 -mmin -$HARVEST_PERIOD`" == "" ] ; then
    touch /var/www/local/harvest/alma/last_harvest.txt
    nohup /var/www/vufind/harvest/harvest_oai.sh >> /var/www/vufind/harvest/harvest_oai.log 2>&1
fi

HARVEST_PERIOD=1440
if [ "`find /var/www/local/harvest/harvest_degruyter.json -maxdepth 0 -mmin -$HARVEST_PERIOD`" == "" ] ; then
    touch /var/www/local/harvest/harvest_degruyter.json
    nohup /var/www/vufind/harvest/harvest_degruyter.sh /var/www/local/harvest/harvest_degruyter.json $DEGRUYTER_PSWD >> /var/www/vufind/harvest/harvest_degruyter.log 2>&1
fi

exit $RET
