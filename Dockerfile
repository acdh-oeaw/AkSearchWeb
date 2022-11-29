FROM php:7-apache
# see https://github.com/mlocati/docker-php-extension-installer#downloading-the-script-on-the-fly
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
COPY local /var/www/local
COPY start.sh /var/www/start.sh
RUN apt update &&\
    apt install -y git zip mariadb-client vim lftp &&\
    echo 'syntax on\nfiletype plugin indent on\nset tabstop=4\nset shiftwidth=4\nset expandtab' > /root/.vimrc &&\
    ### PHP config \
    chmod +x /usr/local/bin/install-php-extensions &&\
    sync &&\
    install-php-extensions gd intl ldap mysqli soap xml xsl zip @composer-2 &&\
    cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" &&\
    ### AkSearch - hopefully composer in the future \
    git clone --depth 1 --recurse-submodules https://github.com/acdh-oeaw/aksearch.git /usr/local/vufind &&\
    ### Apache \
    a2enmod rewrite &&\
    ln /var/www/local/config/vufind/httpd-vufind.conf /etc/apache2/conf-enabled/vufind.conf &&\
    sed -i '/^<\/Location>/i #SetEnv APPLICATION_ENV ""' /etc/apache2/conf-enabled/vufind.conf &&\
    # environment variables are set by the start.sh script (which allows setting them by `docker run`) \
    sed -i -e 's/ SetEnv/ #SetEnv/g' /etc/apache2/conf-enabled/vufind.conf &&\
    # /var/www is www-data user home - ownership allows composer to create cache, etc. \
    chown -R www-data:www-data /var/www /usr/local/vufind &&\
    ### Other \
    ln -s /usr/local/vufind /var/www/vufind 
# VuFind/AkSearch will include it automatically
COPY composer.json /usr/local/vufind/composer.local.json
# DeGruyter harvesting script
COPY harvest_degruyter.php /var/www/vufind/harvest/harvest_degruyter.php
# wrappers assuring only one copy runs at once
COPY harvest_oai.sh /var/www/vufind/harvest/harvest_oai.sh
COPY harvest_degruyter.sh /var/www/vufind/harvest/harvest_degruyter.sh
COPY health_check_and_harvest.sh /var/www/vufind/harvest/health_check_and_harvest.sh
### AkSearch config tuning which can be done as a www-data user
USER www-data
RUN cd /usr/local/vufind &&\ 
    # remove automatic installation of solr and swaggerui \
    sed -i -e '/phing-install-dependencies/d' composer.json &&\
    # for composer v2 compatibility \
    composer config allow-plugins true &&\
    sed -i -e 's/composer-merge-plugin".*/composer-merge-plugin": "^2",/g' composer.json &&\
    composer update -o --no-dev &&\
    # second time for the wikimedia/composer-merge-plugin to work (wasn't installed a line before) \
    composer update -o --no-dev &&\
    # setup swaggerui \
    vendor/bin/phing installswaggerui &&\
    # overwrite LuceneSyntaxHelper class (https://redmine.acdh.oeaw.ac.at/issues/20174) \
    cp vendor/acdh-oeaw/aksearch-ext/override/LuceneSyntaxHelper.php module/VuFindSearch/src/VuFindSearch/Backend/Solr/LuceneSyntaxHelper.php &&\
    mkdir /var/www/cache
USER root
WORKDIR /usr/local/vufind
CMD ["/var/www/start.sh"]
ENV VUFIND_HOME=/usr/local/vufind VUFIND_LOCAL_DIR=/var/www/local VUFIND_CACHE_DIR=/var/www/cache VUFIND_LOCAL_MODULES=AkSearch,AkSearchApi,AkSearchConsole,AkSearchSearch,aksearchExt
