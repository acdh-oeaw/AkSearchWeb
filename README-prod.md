# VuFind 10 deployment

The production Compose file runs the VuFind 10 PHP 8.4 web image with its matching Solr image and a MariaDB 10.11 database. Compose volumes use the `aksearch-vufind10-prod` project name by default, separate from the isolated development stack.

Create the populated environment file on the deployment host, outside this checkout. Start from `.env.vufind10.prod.example`, set unique database credentials and the production Alma and De Gruyter credentials, and add proxy values if the host requires them. Do not commit the populated file or place credentials in `local/` configuration.

Validate the environment and start the services with:

```sh
docker compose --env-file /etc/aksearch/vufind10.env -f docker-compose.yaml config --quiet
docker compose --env-file /etc/aksearch/vufind10.env -f docker-compose.yaml up -d
```

Check startup with `docker compose --env-file /etc/aksearch/vufind10.env -f docker-compose.yaml logs -f web`. Stop the deployment with `docker compose --env-file /etc/aksearch/vufind10.env -f docker-compose.yaml down`; omit `-v` to retain the indexes, database, thumbnails, and harvests. Keep the existing production deployment and its data available until staging acceptance and production checks pass.

The web image is published by the `vufind10` build workflow. Deploy only after that workflow has completed successfully and the staging instance has passed the record, holdings, search, and harvest checks listed in the migration plan.
