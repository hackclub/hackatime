# Hackatime README

[![Ping](https://status.hackatime.hackclub.com/api/badge/1/ping)](https://status.hackatime.hackclub.com/status/hackatime)
[![Status](https://status.hackatime.hackclub.com/api/badge/1/status)](https://status.hackatime.hackclub.com/status/hackatime)
[![Work time](https://hackatime-badge.hackclub.com/U0C7B14Q3/harbor)](https://hackatime-badge.hackclub.com)

## Local development

```sh
# Set it up...
$ git clone https://github.com/hackclub/harbor && cd harbor

# Set your config
$ cp .env.example .env
```

Edit your `.env` file to include the following:

```
# Database configurations - these work with the Docker setup
DATABASE_URL=postgres://postgres:secureorpheus123@db:5432/app_development
WAKATIME_DATABASE_URL=postgres://postgres:secureorpheus123@db:5432/app_development
SAILORS_LOG_DATABASE_URL=postgres://postgres:secureorpheus123@db:5432/app_development

# Generate these with `rails secret` or use these for development
SECRET_KEY_BASE=alallalalallalalallalalalladlalllalal
ENCRYPTION_PRIMARY_KEY=32characterrandomstring12345678901
ENCRYPTION_DETERMINISTIC_KEY=32characterrandomstring12345678902
ENCRYPTION_KEY_DERIVATION_SALT=16charssalt1234
```


## Build & Run the project
```
$ docker compose run --service-ports web /bin/bash

# Now, setup the database using:
app# bin/rails db:create db:schema:load db:seed

# Now you're inside docker & you can do all the fun rails things...
app# bin/rails s -b 0.0.0.0 # this hosts the server on your computer w/ default port 3000
app# bin/rails c # start an interactive irb!
app# bin/rails db:migrate # migrate the database
```

You can now access the app at http://localhost:3000/

Use email authentication from the homepage with test@example.com (you can view emails at http://localhost:3000/letter_opener)!

Ever need to setup a new database?

```
# inside the docker container, reset the db
app# $ bin/rails db:drop db:create db:migrate db:seed
```
