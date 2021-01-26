#!/bin/bash

export VUFIND_HOME=${VUFIND_HOME:=/usr/local/vufind}
export VUFIND_LOCAL_DIR=${VUFIND_LOCAL_DIR:=/var/www/local}

function cfgReplace {
    for cfgfile in `grep -Rl -E "$1" $VUFIND_HOME/config`; do
        sed -i -E "s~$1~$2~g" $cfgfile
    done
    for cfgfile in `grep -Rl -E "$1" $VUFIND_LOCAL_DIR/config`; do
        sed -i -E "s~$1~$2~g" $cfgfile
    done
}

echo "Startup configuration"

### Alma
if [ "$ALMA_KEY" == "" ]; then
    echo "ALMA_KEY environment variable not set"
    exit 1
fi
sed -i -E "s|^key *=.*|key = $ALMA_KEY|g" $VUFIND_LOCAL_DIR/config/vufind/Alma.ini
if [ "$ALMA_URL" != "" ]; then
    sed -i -E "s|^url *=.*|url = $ALMA_URL|g" $VUFIND_LOCAL_DIR/config/vufind/Alma.ini
fi

### Database-related stuff
if [ "$DB_PSWD" == "" ]; then
    echo "DB_PSWD environment variable not set"
    exit 1
fi
if [ "$DB_HOST" == "" ]; then
    echo "DB_HOST environment variable not set"
    exit 1
fi
DB_USER=${DB_USER:=vufind}
DB_NAME=${DB_NAME:=vufind}
DB_ROOT=${DB_ROOT:=root}
DB_CONN_STR="mysql://$DB_USER:$DB_PSWD@$DB_HOST/$DB_NAME"

for i in {1..5}; do
    dbok=`mysql -h "$DB_HOST" -u "$DB_USER" "-p$DB_PSWD" -e "show databases;"`
    if [ "$dbok" == "" ]; then
        dbok=`mysql -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "show databases;"`
    fi
    if [ "$?" == "0" ]; then
        break
    fi
    sleep 1
done
if [ "$?" != "0" ]; then
    echo "Wrong database connection settings - check DB_HOST, DB_USER, DB_PSWD, DB_ROOT and DB_ROOT_PSWD environment variables"
    exit 1
fi
dbok=`echo "$dbok" | grep "$DB_NAME"`
if [ "$dbok" == "" ]; then
    echo "Database doesn't exist - creating"
    mysql -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME" &&\
    mysql -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "DROP USER IF EXISTS '$DB_USER'@'%'" &&\
    mysql -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PSWD'" &&\
    mysql -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%' WITH GRANT OPTION" &&\
    mysql -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "FLUSH PRIVILEGES" &&\
    mysql -h "$DB_HOST" -u "$DB_USER" "-p$DB_PSWD" -D "$DB_NAME" < $VUFIND_HOME/module/VuFind/sql/mysql.sql
fi

if [ ! -e "$VUFIND_LOCAL_DIR/config/vufind/config.ini" ]; then
    mkdir -p "$VUFIND_LOCAL_DIR/config/vufind" &&\
    cp "$VUFIND_HOME/config/vufind/config.ini" "$VUFIND_LOCAL_DIR/config/vufind/config.ini"
fi
sed -i -e "s|^database *=.*|database = $DB_CONN_STR|g" "$VUFIND_LOCAL_DIR/config/vufind/config.ini"

### Update Solr URL in config files
if [ "$SOLR_URL" == "" ]; then
    echo "SOLR_URL environment variable not set"
    exit 1
fi
cfgReplace '^url *=.*http.+/solr' "url = $SOLR_URL"

### Apache
sed -i -E "s|^.*SetEnv +VUFIND_LOCAL_DIR.*|SetEnv VUFIND_LOCAL_DIR \"$VUFIND_LOCAL_DIR\"|g" /etc/apache2/conf-enabled/vufind.conf

### Run Apache
echo "Starting Apache..."
apache2-foreground
