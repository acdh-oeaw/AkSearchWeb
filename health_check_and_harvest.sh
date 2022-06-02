#!/bin/bash
curl http://127.0.0.1/vufind/ > /dev/null 2>&1
RET=$?

HARVEST_PERIOD=360
if [ "`find /var/www/local/harvest/alma -maxdepth 1 -mmin -$HARVEST_PERIOD -name last_harvest.txt`" == "" ] ; then
    /var/www/vufind/harvest/harvest_oai.sh
    touch /var/www/local/harvest/alma/last_harvest.txt
fi

HARVEST_PERIOD=1440
if [ "`find /var/www/local/harvest -maxdepth 1 -mmin -$HARVEST_PERIOD -name harvest_degruyter.json`" == "" ] ; then
    /var/www/vufind/harvest/harvest_degruyter.sh
    touch /var/www/local/harvest/harvest_degruyter.json
fi

exit $RET
