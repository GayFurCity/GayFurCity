execute these commands in order:
* `docker compose up --no-start`
* `migrate/volumes.sh`
* `migrate/database.sh`
* `migrate/fixer.sh`
* `migrate/reindex.sh`
* `docker compose run --rm gayfurcity rake db:migrate`
* `docker compose up -d`
