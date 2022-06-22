#!/bin/bash
curl http://127.0.0.1/vufind/ > /dev/null 2>&1
RET=$?

exit $RET
