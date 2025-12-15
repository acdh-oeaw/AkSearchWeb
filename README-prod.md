# Dedicated production VM setup

## System setup

Making things work behind the proxy

* git
  ```
  git config --global http.proxy http://fifi.arz.oeaw.ac.at:8080/
  ```
* docker
  ```
  mkdir /etc/systemd/system/docker.service.d
  cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOL
  [Service]
  Environment="HTTP_PROXY=http://fifi.arz.oeaw.ac.at:8080/"
  Environment="HTTPS_PROXY=http://fifi.arz.oeaw.ac.at:8080/"
  Environment="NO_PROXY=127.0.0.1,localhost,10.3.6.33"
  EOL
  systemctl daemon-reload
  systemctl restart docker
  ```

## Deployment

A custom systemd service using docker-compose with the [docker-compose.yaml](https://github.com/acdh-oeaw/AkSearchWeb/blob/main/docker-compose-prod.yaml) in '/opt/prod`.

```
cat > /etc/systemd/system/oeaw_resources_prod.service <<EOL
[Unit]
Description=OEAW Resources Production Instance
Wants=docker.service
After=docker.service

[Service]
Type=simple
Restart=always
WorkingDirectory=/opt/prod
ExecStart=/usr/bin/docker-compose up

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl start oeaw_resources_prod
systemctl enable oeaw_resources_prod
```

### Cron jobs

Harvesting and indexing cron jobs set up on root user account.

```
### Redeployment
*/5 * * * * /opt/prod/pull_redeploy.sh 
### Thumbnails
20 * * * * docker run --rm -v prod_thumbnails:/var/www/cache/covers --entrypoint /bin/sh nondef/thumbnailfetcher:latest -c 'node dist/bin/index.js  fetch -p https://raw.githubusercontent.com/acdh-oeaw/AkSearchWeb/main/local/config/thumbnailfetcher/basis_archive.json -a && chown -R 33:33 /var/www/cache/covers' > /opt/prod/log/fetch-thumbnails.log 2>&1
### Harvesting
05 * * * * docker exec prod_web_1 /bin/sh -c 'flock -n /tmp/harvest_archive-basis.lock -c "/var/www/vufind/harvest/harvest_oai.sh archive_basis"' > /opt/prod/log/harvest_archive_basis.log 2>&1
10 * * * * docker exec prod_web_1 /bin/sh -c 'flock -n /tmp/harvest_archive-oeai.lock  -c "/var/www/vufind/harvest/harvest_oai.sh archive_oeai"'  > /opt/prod/log/harvest_archive-oeai.log  2>&1
15 * * * * docker exec prod_web_1 /bin/sh -c 'flock -n /tmp/harvest_bib-alma.lock      -c "/var/www/vufind/harvest/harvest_oai.sh bib_alma && chown -R 8983:www-data /var/www/local/harvest/bib_alma && [ -f /var/www/local/harvest/bib_alma/*.delete ] && { sed -i \"s/oai:alma.43ACC_OEAW://g\" /var/www/local/harvest/bib_alma/*.delete; /usr/local/vufind/harvest/batch-delete.sh ../../../../var/www/local/harvest/bib_alma/; } || echo \"No deletions submitted.\""' > /opt/prod/log/harvest_bib-alma.log 2>&1
00 0 1 * * docker exec prod_web_1 /bin/sh -c 'flock -n /tmp/harvest_degruyter.lock     -c "/var/www/vufind/harvest/harvest_degruyter.sh /var/www/local/harvest/harvest_degruyter.json $DEGRUYTER_PSWD && chown -R 8983:www-data /var/www/local/harvest/bib_degruyter"' > /opt/prod/log/harvest_degruyter.log 2>&1
### Indexing
35 * * * * docker exec prod_solr_1 /bin/sh -c 'flock -n /tmp/index_archive-basis.lock -c "cd /opt/aksearch && harvest/batch-import-marc.sh -d -p /opt/local/import/import_archive_basis.properties /opt/harvest/archive_basis"' > /opt/prod/log/index_archive-basis.log 2>&1
40 * * * * docker exec prod_solr_1 /bin/sh -c 'flock -n /tmp/index_archive-oeai.lock  -c "cd /opt/aksearch && harvest/batch-import-marc.sh -d -p /opt/local/import/import_archive_oeai.properties  /opt/harvest/archive_oeai"'  > /opt/prod/log/index_archive-oeai.log  2>&1
45 * * * * docker exec prod_solr_1 /bin/sh -c 'flock -n /tmp/index_bib-alma.lock      -c "cd /opt/aksearch && harvest/batch-import-marc.sh -d -p /opt/local/import/import_bib_alma.properties      /opt/harvest/bib_alma"'      > /opt/prod/log/index_bib-alma.log      2>&1
30 0 1 * * docker exec prod_solr_1 /bin/sh -c 'flock -n /tmp/index_degruyter.lock     -c "cd /opt/aksearch && harvest/batch-import-marc.sh -d -p /opt/local/import/import_bib_degruyter.properties /opt/harvest/bib_degruyter"' > /opt/prod/log/index_bib-degruyter.log 2>&1
```

#### Redeployment script:

```
cat > /opt/prod/pull_redeploy.sh <<EOL
#!/bin/bash
for i in \`docker ps --format '{{.Image}}' | grep -E '/|:'\` ; do 
    docker pull \$i
done
# if any running container runs an untagged image, restart
docker ps -f name=prod_* --format '{{.Image}}' | grep -q -v -E '/|:'
if [ "\$?" == "0" ] ; then
    systemctl restart oeaw_resources_prod
    docker image prune -f
fi
EOL
chmod +x /opt/prod/pull_redeploy.sh
```

## Reverse proxy

Ask ARZ to proxy the https://www.oeaw.ac.at/resources/ to the http://10.3.6.33:8080/resources/

