FROM php:8.4-apache
# see https://github.com/mlocati/docker-php-extension-installer#downloading-the-script-on-the-fly
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
COPY local /var/www/local
COPY start.sh /var/www/start.sh
RUN apt update &&\
    apt install -y git zip mariadb-client vim lftp libapache2-mod-evasive nodejs npm grunt&&\
    echo 'syntax on\nfiletype plugin indent on\nset tabstop=4\nset shiftwidth=4\nset expandtab' > /root/.vimrc &&\
    ### PHP config \
    chmod +x /usr/local/bin/install-php-extensions &&\
    sync &&\
    install-php-extensions gd intl ldap mysqli soap xml xsl zip @composer-2 &&\
    cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
RUN a2enmod rewrite &&\
    a2enmod remoteip &&\
    # Use vanila VuFind for a base and AkSearch only as modules but skip the main aksearch repo
    git clone --depth 1 -b v10.1.1 https://github.com/vufind-org/vufind.git /usr/local/vufind &&\
    git clone --depth 1 -b aksearch-10 https://biapps.arbeiterkammer.at/gitlab/open/aksearch/module-core.git    /usr/local/vufind/module/AkSearch &&\
    git clone --depth 1 -b aksearch-10 https://biapps.arbeiterkammer.at/gitlab/open/aksearch/module-api.git     /usr/local/vufind/module/AkSearchApi &&\
    git clone --depth 1 -b aksearch-10 https://biapps.arbeiterkammer.at/gitlab/open/aksearch/module-console.git /usr/local/vufind/module/AkSearchConsole &&\
    git clone --depth 1 -b aksearch-10 https://biapps.arbeiterkammer.at/gitlab/open/aksearch/module-search      /usr/local/vufind/module/AkSearchSearch &&\
    ### Apache \
    chown -R www-data:www-data /var/www /usr/local/vufind &&\
    ln -s /var/www/local/config/vufind/httpd-vufind.conf /etc/apache2/conf-enabled/vufind.conf &&\
    ln -s /usr/local/vufind /var/www/vufind
# VuFind/AkSearch will include it automatically
COPY composer.json /usr/local/vufind/composer.local.json
# After cloning of the vufind/aksearch repo in /usr/local/vufind/harvest
COPY harvest/* /usr/local/vufind/harvest/
### VuFind config tuning which can be done as a www-data user
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
    mkdir /var/www/cache
# AkSearch dirty hacks
#   Incompatible with PHP 8.4 class inheritance but anyway defined in the parent class
#   The only other way to fix it would be to copy-paste to aksearch-ext and fix it there which is even more ugly
RUN sed -i -e '/protected \$results;/d' /usr/local/vufind/module/AkSearch/src/AkSearch/Search/Solr/FacetCache.php
USER root
WORKDIR /usr/local/vufind
CMD ["/var/www/start.sh"]
ENV VUFIND_HOME=/usr/local/vufind VUFIND_LOCAL_DIR=/var/www/local VUFIND_CACHE_DIR=/var/www/cache VUFIND_LOCAL_MODULES=AkSearch,AkSearchApi,AkSearchConsole,AkSearchSearch,aksearchExt
