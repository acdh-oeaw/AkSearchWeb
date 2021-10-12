# AkSearchWeb

A Docker image providing a runtime environment for the [AkSearch](https://biapps.arbeiterkammer.at/gitlab/open/aksearch/aksearch) web component.

It depends on a Solr instance and MySQL/MariaDb instance:

* The Solr instance can be deployed using the [AkSearchSolr](https://github.com/acdh-oeaw/aksearchsolr) docker image.
* The MariaDb can be deployed using the official [MariaDb](https://hub.docker.com/_/mariadb) docker image.

Both of them can be deployed usind the `docker-compose.yaml` located in this repository root - see the corresponding section below.

You must pass information about location of Solr and MySQL/MariaDb database using environment variables (see the *Environment variables* section below).

## Deployment on ACDH servers

Deployment on Portainer is done automatically (there is a service checking for new versions of docker images on docker hub and redeploying services when a new version is available).

### Harvesting with OAI-PMH

Run `/var/www/vufind/harvest/harvest_oai.sh` inside the container (e.g. with `docker exec {containerName} /var/www/vufind/harvest/harvest_oai.sh`).

## Local deployment

Use `docker run`, e.g. (just adjust environment variable values!) :

```
docker run -d -p 80:80 --name aksearch-web -e DB_HOST=db.host -e DB_PSWD=strongPswd -e SOLR_URL=http://my.solr/solr -e ALMA_KEY=xxx aksearch-web
```

If connections with Solr and MySQL/MariaDb database works fine, you should be able to open the AkSearch in your browser using the http://127.0.0.1/vufind/ URL.

### Environment variables

| Environment Variable | Required | Default | Description                                                            |
|----------------------|----------|---------|------------------------------------------------------------------------|
| SOLR_URL             |    +     |         | URL of the Solr backend, e.g. http://my.server:8983/solr               |
| ALMA_KEY             |    +     |         | Your Alma API authorization token                                      |
| ALMA_URL             |    +     | https://api-eu.hosted.exlibrisgroup.com/almaws/v1 | Base URL of the Alma API     |
| DB_HOST              |    +     |         | Server name/IP of your MySQL/MariaDb database                          |
| DB_PSWD              |    +     |         | Password for your MySQL/MariaDb database                               |
| DB_USER              |          | vufind  | User name for accessing your MySQL/MariaDb database                    |
| DB_NAME              |          | vufind  | Your MySQL/MariaDb database name                                       |
| DB_ROOT              |   +/-    | root    | Name of your MySQL/MariaDb database superuser account (see below)      |
| DB_ROOT_PSWD         |   +/-    |         | Password for your MySQL/MariaDb database superuser account (see below) |
| VUFIND_LOCAL_MODULES |          | AkSearch,AkSearchApi, AkSearchConsole,AkSearchSearch,aksearchExt | Coma separarated list of Zend2 modules to be enabled (on top of VuFind ones) |
| APPLICATION_ENV      |          |         | Set to 'development' to avoid Zend configuration caching (which may cause troubles with live development) and enable verbose error messages (this value is also copied VUFIND_ENV) |

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

## Keeping up to date

Docker doesn't update images automatically, so every time you want to make sure you are using an up to date version run `docker pull acdhch/aksearch-web`.

Same goes for other images (in our case `acdhch/aksearch-solr` for the Solr backend and `mariadb:10` for the MariaDb backend).

If you are using `docker-compose`, you can run `docker-compose pull` to update all of them at once.

## Extending

* Modify VuFind/AkSearch **configuration files** by adding adjusted versions to the `local` directory of this repo.
    * **By no means add any confidential data to this repository** (e.g. API tokens, database passwords, etc.).
      Such a data should be passed only using environment variables at runtime and the `start.sh` script should put them in the right target places.
      If you don't know how to do it, contact Mateusz.
* If you modify **application code**:
    * Develop it in a separate repository and deploy it as a composer package.
    * Indicate that this image depends on it by adding corresponding composer package name (and version) to the `composer.json` file in this repository root.
* If you create a new **theme**:
    * Develop it in a separate repository and deploy it as a composer package.
    * Indicate that this image depends on it by adding corresponding composer package name (and version) to the `composer.json` file in this repository root.
    * Add creating of a symlink from the VuFind/AkSearch installation dir to the directory where composer installs your theme package to the `start.sh` script.
* Commit changes to this repository and push it to GitHub.
    * The acdhch/aksearch-web image will be rebuild automatically.
      Depending on Docker Hub servers load it can take from few minutes to an hour.
    * If you don't want to wait, you can build the image on your own.
      Just run `docker build -t acdhch/aksearch-web pathToThisRepoOnYourMachine`.
      In such a case you can skip the next step.
* Pull the current acdhch/aksearch-web image to your local docker registry (run `docker pull acdhch/aksearch-web`)

### Checking how your packages work with VuFind/AkSearch

While developing your packages you might want to test the *live*. For that just mount your module sources under `/var/www/vufind/vendor/{yourAccount}/{yourPackage}` in the `aksearch-web` container.

Same goes with testing live the changes you are making in this repository's `local` directory. Just mount this directory under `/var/www/local` in `aksearch-web` container.

See the *Appendix - useful Docker commands* below for instructions on mounting host directories in a Docker container.

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
    * To shut down containers just hit `CTRL+C` on the console where `docker-compose up` displays containers' logs.

## Importing sample data

Follow instructions in the [AkSearchSolr](https://github.com/acdh-oeaw/AkSearchSolr#importing-sample-marc-data) repository.

## Appendix - useful Docker commands

If you are a Docker newbie:

* `docker ps -a` lists containers and their state.
* `docker exec -ti container_name bash` runs a console inside a given container (something like using ssh to get a console on a remote server).
* `docker rm -fv container_name` removes a given container.
* `docker volume list` lists all defined volumes. Volumes are like disk partitions - they provide persistent storage which survives container removal. There are a few tricky things about them:
    * As they survive container removal, you must remove them by hand (see below) to fully clean up your machine.
    * If a volume doesn't exist, it's created empty (it especially meand that if you mount it under `/some/path` in the container, `/some/path` content from the container's image won't be copied to the volume). This means if you need volumes to be initially filled with data, your container's startup scripts must take care of it (e.g. https://github.com/acdh-oeaw/AkSearchSolr/blob/main/aksearch.sh in the Solr container here - *if Solr cores directory is empty, initialize it with a template, otherwise do nothing*)
    * You can't see volumes content directly from host filesystem (at least without using black magick ;-) ). On one hand that's inconvenient but on the other it allows to avoid all the file permissions issues (for smooth sharing files between the host and a docker container the host and the container should also share users and groups database which is rarely a case).
* `docker volume rm volume_name` removes a given volume. As volumes survive container removal you must delete them by hand to fully clean up your machine.

### Mounting host directories inside a Docker container

Let's say you want to mount the `d:/my/host/dir` under `/container/dir` in a Docker container.

* If you run the container using `docker run`, just add a `-v d:/my/host/dir:/container/dir` to the `docker run` call.
* If you are using `docker-compose up` and the `docker-composer.yaml`, add a corresponding `volume` section to your container definition, e.g.:
  ```yaml
  services:
    ak-web:
      volumes:
      - d:/my/host/dir:/container/dir
  ```

**Be aware** that mounting data from host into a Docker container may cause file permissions issues. The user account used for running the code inside the Docker container may have unsufficient priviledges to access (less likely) or create/modify (very likely) data you mounted from host. There are three workarounds. First, granting everyone read/write rights on the data you are mounting (you should grant them in the host system). Second, use the root account inside the Docker container. Third, synchronize UIDs of the host and Docker container user accounts (but if you are reading this sentence, you should stick to the first or second workaround).

