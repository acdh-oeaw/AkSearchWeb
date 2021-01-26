# AkSearchWeb

A Docker image providing a runtime environment for the [AkSearch](https://biapps.arbeiterkammer.at/gitlab/open/aksearch/aksearch) web component.

It depends on a Solr instance and MySQL/MariaDb instance:

* The Solr instance can be deployed using the [AkSearchSolr](https://github.com/acdh-oeaw/aksearchsolr) docker image.
* The MariaDb can be deployed using the official [MariaDb](https://hub.docker.com/_/mariadb) docker image.

Both of them can be deployed usind the `docker-compose.yaml` located in this repository root - see the corresponding section below.

You must pass information about location of Solr and MySQL/MariaDb database using environment variables (see the *Environment variables* section below).

## Deployment

Use `docker run`, e.g. (just adjust environment variable values!) :

```
docker run -d -p 80:80 --name aksearch-web -e DB_HOST=db.host -e DB_PSWD=strongPswd -e SOLR_URL=http://my.solr/solr -e ALMA_KEY=xxx aksearch-web
```

If connections with Solr and MySQL/MariaDb database works fine, you should be able to open the AkSearch in your browser using the http://127.0.0.1/vufind/ URL.

### Environment variables

| Env Var      | Required | Default | Description                                                            |
|--------------|----------|---------|------------------------------------------------------------------------|
| SOLR_URL     |    +     |         | URL of the Solr backend, e.g. http://my.server:8983/solr               |
| ALMA_KEY     |    +     |         | Your Alma API authorization token                                      |
| DB_HOST      |    +     |         | Server name/IP of your MySQL/MariaDb database                          |
| DB_PSWD      |    +     |         | Password for your MySQL/MariaDb database                               |
| DB_USER      |          | vufind  | User name for accessing your MySQL/MariaDb database                    |
| DB_NAME      |          | vufind  | Your MySQL/MariaDb database name                                       |
| DB_ROOT      |   +/-    | root    | Name of your MySQL/MariaDb database superuser account (see below)      |
| DB_ROOT_PSWD |   +/-    |         | Password for your MySQL/MariaDb database superuser account (see below) |

#### DB_ROOT_PSWD and DB_ROOT

If `DB_ROOT_PSWD` (and `DB_ROOT`) environment variables are provided, the startup script will check if a `DB_USER` account and `DB_NAME` database exist and create them when needed.

The container can still successfully start up without these environment variables if only the database has been already created (e.g. if you did it manually or you already have one as you are e.g. migrating from already existing VuFind/AkSearch instance).

### Providing own VuFind/AkSearch settings

FuVind/AkSearch allows you to overwrite settings by providing a *shadow directory* with your own ones.
It works in a way that if a file with a given relative path exists both in VuFind/AkSearch main code tree and your *shadow directory*, the *shadow directory* file is being used.

Typically such a *shadow directory* is used to overwritte files in VuFind/AkSearch `config` directory.
Some examples are even provided in the AkSearch repo - the [local](https://biapps.arbeiterkammer.at/gitlab/open/aksearch/aksearch/tree/aksearch/local) directory is indeed such a *shadow directory*.

The default *shadow directory* for this image is provided by the [local](https://github.com/acdh-oeaw/AkSearchWeb/tree/main/local) directory of this repository.

If you want to overwrite it with a directory from your machine, just add a `-v /full/path/on/your/machine:/var/www/local` to the `docker run` call.

If you are using `docker-compose.yaml` you can achieve the same by adding a `volumes` section to the `ak-web` container definition:
```yaml
services:
  ak-web:
    volumes:
    - /full/path/on/your/machine:/var/www/local
```

## Solr and/or MariaDb deployment using attached docker-compose.yaml

The easiest way to deploy dependencies is to use the `docker-compose.yaml` file provided by this repository.

* Download https://github.com/acdh-oeaw/AkSearchWeb/blob/main/docker-compose.yaml.
* Open it and adjust:
    * Change passwords (`MYSQL_ROOT_PASSWORD`, `DB_PSWD`, `DB_ROOT_PSWD`, be aware `MYSQL_ROOT_PASSWORD` and `DB_ROOT_PSWD` have to be equal)
    * If you already have a Solr or MySQL/MariaDb database remove corresponding parts of the file
      (and make sure environment variables in the `services->ak-web->environment` are in line with your already existing service config)
    * If you want direct access to Solr and/or MariaDb, add a `ports` section to their definitions (just like it's done for the `ak-web`).
      Solr works on port 8983 while MariaDb on 3306.
      The reason for not providing such mappings is the `docker-compose.yaml` is that it makes both services easily accessible which might be not desiread as e.g. Solr has no authorization by default.
* Open console, go to the directory with the `docker-compose.yaml` and run
  ```bash
  docker-compose up
  ```

