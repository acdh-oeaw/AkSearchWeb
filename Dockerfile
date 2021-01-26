FROM php:7-apache
# see https://github.com/mlocati/docker-php-extension-installer#downloading-the-script-on-the-fly
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
COPY local /var/www/local
COPY start.sh /var/www/start.sh
COPY composer.json /var/www/composer.json
RUN apt update &&\
    apt install -y git zip mariadb-client &&\
    ### PHP config \
    chmod +x /usr/local/bin/install-php-extensions &&\
    sync &&\
    install-php-extensions gd intl ldap mysqli soap zip @composer-1 &&\
    cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" &&\
    ### AkSearch - hopefully composer in the future \
    git clone --depth 1 https://biapps.arbeiterkammer.at/gitlab/open/aksearch/aksearch.git /usr/local/vufind &&\
    ### Apache \
    a2enmod rewrite &&\
    ln -s /usr/local/vufind/config/vufind/httpd-vufind.conf /etc/apache2/conf-enabled/vufind.conf &&\
    # environment variables are set by the start.sh script (which allows setting them by `docker run`) \
    sed -i -e 's/ SetEnv/ #SetEnv/g' /etc/apache2/conf-enabled/vufind.conf &&\
    # /var/www is www-data user home - ownership allows composer to create cache, etc. \
    chown -R www-data:www-data /var/www /usr/local/vufind &&\
    ### Other \
    ln -s /usr/local/vufind /var/www/vufind 
### AkSearch config tuning which can be done as a www-data user
COPY install_deps.php /var/www/install_deps.php
USER www-data
RUN cd /usr/local/vufind &&\
    # remove autoinstallation code - solr is in a separate container and we don't need swaggerui \
    sed -i -e 's/^.*@phing-install-dependencies.*$//g' -e 's/"phing installsolr installswaggerui",/"phing installsolr installswaggerui"/g' composer.json &&\
    # can be removed when AkSearch will become a composer package \
    /var/www/install_deps.php /var/www/composer.json &&\
    composer update
USER root
CMD ["/var/www/start.sh"]
ENV VUFIND_HOME=/usr/local/vufind VUFIND_LOCAL_DIR=/var/www/local
