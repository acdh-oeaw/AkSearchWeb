#!/bin/bash

if [ "$1" = "" ] ; then
    echo "$0 password [login] [stack_name] [portainer_api_base]"
    echo ""
    echo "Reingests OEAW resources' Solr database."
    echo "It's done by removing volumes storing Solr data and records harvested with OAI-PMH and restarting the whole indexing process. "
    echo ""
    echo "Parameters:"
    echo '  password, login - Portainer credentialsi (login default value "admin")'
    echo '  stack_name - OEAW resources Portainer stack name (default value "resources")'
    echo '  portainer_api_base - Portainer REST API base URL (default value "https://portainer.sisyphos.arz.oeaw.ac.at/api")'
    echo ""
    exit
fi

PSWD=$1
LOGIN=$2
LOGIN=${LOGIN:="admin"}
STACK_NAME=$3
STACK_NAME=${STACK_NAME:="resources"}
APIURL=$4
APIURL=${APIURL:="https://portainer.sisyphos.arz.oeaw.ac.at/api"}

function check_request () {
    CODE=`echo -e "$1" | head -n 1 | tr -d '\r\n'`
    if [ "$CODE" != "HTTP/2 200 " ] && [ "$CODE" != "HTTP/2 204 " ] ; then
        echo -e "   failed\n\n$1"
        exit 1
    fi
    echo "   succeeded"
}

TOKEN=`curl -s -S "$APIURL/auth" -H "Content-Type: application-json" --data-binary "{\"Username\": \"$LOGIN\", \"Password\": \"$PSWD\"}" | jq -r '.jwt'`
STACK_ID=`curl -s -S -H "Authorization: Bearer $TOKEN" "$APIURL/stacks" | jq -r ".[] | select(.Name == \"$STACK_NAME\") | .Id"`

echo "## Stopping the '$STACK_NAME' stack"
R=`curl -s -S -i -H "Authorization: Bearer $TOKEN" -X POST "$APIURL/stacks/$STACK_ID/stop"`
check_request "$R"

VOLUMES=`curl -s -S -H "Authorization: Bearer $TOKEN" https://portainer.sisyphos.arz.oeaw.ac.at/api/endpoints/1/docker/volumes | \
    jq -r ".Volumes[] | select((.Name | startswith(\"${STACK_NAME}_\")) and ((.Name | contains(\"solr\")) or (.Name | contains(\"harvest\")))) | .Name"`
for v in $VOLUMES ; do
    echo "## Removing volume '$v'"
    R=`curl -s -S -i -H "Authorization: Bearer $TOKEN" -X DELETE "$APIURL/endpoints/1/docker/volumes/$v"`
    check_request "$R"
done

echo "## Starting the '$STACK_NAME' stack"
R=`curl -s -S -i -H "Authorization: Bearer $TOKEN" -X POST "$APIURL/stacks/$STACK_ID/start"`
check_request "$R"

CONTAINERS=`curl -s -S -H "Authorization: Bearer $TOKEN" "$APIURL/endpoints/1/docker/containers/json" -G -d "filters={\"label\":[\"com.docker.compose.project=$STACK_NAME\"]}" | \
    jq '.[].Names[]' -r | \
    sed -e 's/^\///g'`
WEB_CONTAINER=`echo -e "$CONTAINERS" | grep web`
SOLR_CONTAINER=`echo -e "$CONTAINERS" | grep solr`

echo "## Reharvesting OAI-PMH records"
docker exec "$WEB_CONTAINER" /var/www/vufind/harvest/harvest_oai.sh
if [ "$?" != "0" ] ; then
    exit 2
fi

echo "## Reingesting data into Solr"
docker exec -u root "$SOLR_CONTAINER" /opt/aksearch/harvest/batch-import-marc-single.sh -d /opt/harvest
if [ "$?" != "0" ] ; then
    exit 3
fi

