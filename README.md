<div align="center">

<img width="456" alt="Hackatime" src="https://github.com/user-attachments/assets/b3036ced-a7ea-4d03-8feb-816a83572e3a#gh-light-mode-only" />
<img width="456" alt="Hackatime" src="https://github.com/user-attachments/assets/1d237c55-d349-44d3-93e6-d9dbb627e4dc#gh-dark-mode-only" />

[![Ping](https://uptime.hackclub.com/api/badge/4/ping)](https://uptime.hackclub.com/status/hackatime)
[![Status](https://uptime.hackclub.com/api/badge/4/status)](https://uptime.hackclub.com/status/hackatime)
[![Work time](https://hackatime-badge.hackclub.com/U0C7B14Q3/harbor)](https://hackatime-badge.hackclub.com)

[**Documentation**](https://hackatime.hackclub.com/docs)

</div>

## Local development

```sh
# Set it up...
$ git clone https://github.com/hackclub/hackatime && cd hackatime

# Set your config
$ cp .env.example .env
```

Edit your `.env` file to include the following:

```env
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

```sh
$ docker compose up -d
$ docker compose exec web /bin/bash

# Now, setup the database using:
app# bin/rails db:create db:schema:load db:seed

# Now start up the app:
app# bin/dev
# This hosts the server on your computer w/ default port 3000

# Want to do other things?
app# bin/rails c # start an interactive irb!
app# bin/rails db:migrate # migrate the database
app# bin/rails rswag:specs:swaggerize # generate API documentation
```

You can now access the app at <http://localhost:3000/>

Use email authentication from the homepage with `test@example.com` or create a new user (you can view outgoing emails at [http://localhost:3000/letter_opener](http://localhost:3000/letter_opener))!

Ever need to setup a new database?

```sh
# inside the docker container, reset the db
app# $ bin/rails db:drop db:create db:migrate db:seed
```
