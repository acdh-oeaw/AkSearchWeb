#!/bin/bash

export VUFIND_HOME=${VUFIND_HOME:=/usr/local/vufind}
export VUFIND_LOCAL_DIR=${VUFIND_LOCAL_DIR:=/var/www/local}
export VUFIND_CACHE_DIR=${VUFIND_CACHE_DIR:=/var/www/cache}

if [ -n "$VUFIND_RUNTIME_LOCAL_DIR" ]; then
    VUFIND_LOCAL_SOURCE_DIR=${VUFIND_LOCAL_SOURCE_DIR:-$VUFIND_LOCAL_DIR}
    mkdir -p "$VUFIND_RUNTIME_LOCAL_DIR"
    cp -a "$VUFIND_LOCAL_SOURCE_DIR"/. "$VUFIND_RUNTIME_LOCAL_DIR"/
    export VUFIND_LOCAL_DIR="$VUFIND_RUNTIME_LOCAL_DIR"
fi

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
sed -i -E "s|^apiKey *=.*|apiKey = $ALMA_KEY|g" $VUFIND_LOCAL_DIR/config/vufind/Alma.ini
if [ "$ALMA_URL" != "" ]; then
    sed -i -E "s|^apiBaseUrl *=.*|apiBaseUrl = $ALMA_URL|g" $VUFIND_LOCAL_DIR/config/vufind/Alma.ini
fi

### Apply an outbound HTTP proxy to VuFind's HTTP client settings.
PROXY_URL=${HTTPS_PROXY:-${HTTP_PROXY:-}}
if [ -n "$PROXY_URL" ]; then
    PROXY_HOST=$(php -r '$u = parse_url($argv[1]); echo $u["host"] ?? "";' "$PROXY_URL")
    PROXY_PORT=$(php -r '$u = parse_url($argv[1]); echo $u["port"] ?? (($u["scheme"] ?? "") === "https" ? 443 : 80);' "$PROXY_URL")
    if [ -z "$PROXY_HOST" ]; then
        echo "Could not parse HTTP_PROXY/HTTPS_PROXY URL"
        exit 1
    fi
    PROXY_CONFIG="$VUFIND_LOCAL_DIR/config/vufind/config.ini"
    PROXY_CONFIG_TMP="$PROXY_CONFIG.tmp"
    if awk -v proxy_host="$PROXY_HOST" -v proxy_port="$PROXY_PORT" -v no_proxy="${NO_PROXY:-}" '
        function writeProxySettings() {
            print "host = " proxy_host
            print "port = " proxy_port
            print "no_proxy = \"" no_proxy "\""
        }
        /^\[Proxy\]$/ {
            print
            inProxy = 1
            foundProxy = 1
            writeProxySettings()
            next
        }
        inProxy && /^\[/ {
            inProxy = 0
        }
        inProxy && /^[[:space:]]*;?[[:space:]]*(host|port|no_proxy)[[:space:]]*=/ {
            next
        }
        { print }
        END {
            if (!foundProxy) {
                exit 1
            }
        }
    ' "$PROXY_CONFIG" > "$PROXY_CONFIG_TMP"; then
        chmod --reference="$PROXY_CONFIG" "$PROXY_CONFIG_TMP"
        mv "$PROXY_CONFIG_TMP" "$PROXY_CONFIG"
    else
        echo "Could not update the [Proxy] section in $PROXY_CONFIG"
        exit 1
    fi
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
DB_ROOT_PSWD=${DB_ROOT_PSWD:=__nopswd__}
DB_USER=${DB_USER:=vufind}
DB_NAME=${DB_NAME:=vufind}
DB_ROOT=${DB_ROOT:=root}
# MariaDB client 11 attempts TLS by default, but the configured MaxScale
# endpoint does not support it. VuFind's PDO connection is configured
# separately; this option applies only to the startup SQL commands below.
mysql_cli() {
    mysql --skip-ssl "$@"
}

for i in {1..10}; do
    dbok=`mysql_cli -h "$DB_HOST" -u "$DB_USER" "-p$DB_PSWD" -e "show databases;"`
    if [ "$dbok" == "" ]; then
        dbok=`mysql_cli -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "show databases;"`
    fi
    if [ "$?" == "0" ]; then
        break
    fi
    sleep 2
done
if [ "$?" != "0" ]; then
    echo "Wrong database connection settings - check DB_HOST, DB_USER, DB_PSWD, DB_ROOT and DB_ROOT_PSWD environment variables"
    exit 1
fi
dbok=`echo "$dbok" | grep "$DB_NAME"`
if [ "$dbok" == "" ]; then
    echo "Database doesn't exist - creating"
    mysql_cli -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME" &&\
    mysql_cli -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "DROP USER IF EXISTS '$DB_USER'@'%'" &&\
    mysql_cli -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PSWD'" &&\
    mysql_cli -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%' WITH GRANT OPTION" &&\
    mysql_cli -h "$DB_HOST" -u "$DB_ROOT" "-p$DB_ROOT_PSWD" -e "FLUSH PRIVILEGES"
fi
dbempty=`mysql_cli -h "$DB_HOST" -u "$DB_USER" "-p$DB_PSWD" -D "$DB_NAME" -e "show tables;" | wc -l`
if [ "$dbempty" == "0" ]; then
    echo "Database is empty - filling in with $VUFIND_HOME/module/VuFind/sql/mysql.sql"
    mysql_cli -h "$DB_HOST" -u "$DB_USER" "-p$DB_PSWD" -D "$DB_NAME" < $VUFIND_HOME/module/VuFind/sql/mysql.sql
fi

if [ ! -e "$VUFIND_LOCAL_DIR/config/vufind/config.ini" ]; then
    mkdir -p "$VUFIND_LOCAL_DIR/config/vufind" &&\
    cp "$VUFIND_HOME/config/vufind/config.ini" "$VUFIND_LOCAL_DIR/config/vufind/config.ini"
fi
DB_PASSWORD_FILE="$VUFIND_LOCAL_DIR/config/vufind/database-password"
umask 077
printf '%s' "$DB_PSWD" > "$DB_PASSWORD_FILE"
chown www-data:www-data "$DB_PASSWORD_FILE"
chmod 600 "$DB_PASSWORD_FILE"
php /tmp/configure-vufind-database.php \
    "$VUFIND_LOCAL_DIR/config/vufind/config.ini" \
    "$DB_HOST" "$DB_USER" "$DB_NAME" "$DB_PASSWORD_FILE"
if [ -n "$VUFIND_SESSION_NAME" ]; then
    SESSION_CONFIG="$VUFIND_LOCAL_DIR/config/vufind/config.ini"
    if grep -qE '^[[:space:]]*session_name[[:space:]]*=' "$SESSION_CONFIG"; then
        sed -i -E "s|^[[:space:]]*session_name[[:space:]]*=.*|session_name = $VUFIND_SESSION_NAME|" "$SESSION_CONFIG"
    else
        sed -i "/^\[Cookies\]/a session_name = $VUFIND_SESSION_NAME" "$SESSION_CONFIG"
    fi
fi
if [ -n "$SITE_URL" ]; then
    sed -i -E "/^\[Site\]/,/^\[/ s|^url[[:space:]]*=.*|url = \"$SITE_URL\"|" "$VUFIND_LOCAL_DIR/config/vufind/config.ini"
fi

### Update Solr URL in config files
if [ "$SOLR_URL" == "" ]; then
    echo "SOLR_URL environment variable not set"
    exit 1
fi
cfgReplace '^url *=.*http.+/solr' "url = $SOLR_URL"

## Install the theme unless a local development mount is already in place.
if [ "$SKIP_THEME_INSTALL" != "true" ]; then
    if [ ! -e "$VUFIND_HOME/themes/AcdhchTheme" ]; then
        mkdir -p "$VUFIND_HOME/themes/AcdhchTheme"
    fi
    cp -rf "$VUFIND_HOME/vendor/acdh-oeaw/ak-search-acdh-theme"/* "$VUFIND_HOME/themes/AcdhchTheme/"
    chown www-data -R "$VUFIND_HOME/themes/AcdhchTheme/"
fi
cd "$VUFIND_HOME/themes/AcdhchTheme/"
php -f utils/compile-sass.php
cd "$VUFIND_HOME"

### Use the proxy-aware OAI harvester factory when supplied by this deployment.
HARVESTER_FACTORY="$VUFIND_HOME/vendor/vufind-org/vufindharvest/src/OaiPmh/HarvesterFactory.php"
if [ -f "$VUFIND_HOME/harvest/HarvesterFactory.php" ] && [ -f "$HARVESTER_FACTORY" ]; then
    ln -sf "$VUFIND_HOME/harvest/HarvesterFactory.php" "$HARVESTER_FACTORY"
fi

### Apache
sed -i -E "s|^.*SetEnv +VUFIND_LOCAL_DIR.*|SetEnv VUFIND_LOCAL_DIR \"$VUFIND_LOCAL_DIR\"|g" /etc/apache2/conf-enabled/vufind.conf
sed -i -E "s|^.*SetEnv +VUFIND_CACHE_DIR.*|SetEnv VUFIND_CACHE_DIR \"$VUFIND_CACHE_DIR\"|g" /etc/apache2/conf-enabled/vufind.conf
sed -i -E "s|^.*SetEnv +VUFIND_LOCAL_MODULES.*|SetEnv VUFIND_LOCAL_MODULES $VUFIND_LOCAL_MODULES|g" /etc/apache2/conf-enabled/vufind.conf
sed -i -E "s|^.*SetEnv +VUFIND_ENV.*|SetEnv VUFIND_ENV \"$APPLICATION_ENV\"|g" /etc/apache2/conf-enabled/vufind.conf
sed -i -E "s|^.*SetEnv +APPLICATION_ENV.*|SetEnv APPLICATION_ENV \"$APPLICATION_ENV\"|g" /etc/apache2/conf-enabled/vufind.conf

echo "Rebuild css...."

#php -f $VUFIND_HOME/util/cssBuilder.php - deprecated as of 10.x
npm install
npm run build:less
npm run install:scss-dependencies
grunt scssonly --force ##force to compile in spite of warnings

### Run Apache
echo "Starting Apache...!"
apache2-foreground


