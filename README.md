<img width="3504" height="2240" alt="image" src="https://github.com/user-attachments/assets/8689e4a8-13f5-4b83-ae8c-b10b6db9c50c" />

<div align="center">
  
# **Hackatime**

[![Ping](https://uptime.hackclub.com/api/badge/4/ping)](https://uptime.hackclub.com/status/hackatime)
[![Status](https://uptime.hackclub.com/api/badge/4/status)](https://uptime.hackclub.com/status/hackatime)
[![Work time](https://hackatime-badge.hackclub.com/U0C7B14Q3/harbor)](https://hackatime-badge.hackclub.com)

[**Documentation**](https://hackatime.hackclub.com/docs)

</div>

**[Hackatime](hackatime.hackclub.com)** allows you to track the time you code, see daily and weekly coding leaderboards, and get statics on projects, languages, and more.

<img width="3504" height="2240" alt="Untitled - 2026-02-17T142454 258 1" src="https://github.com/user-attachments/assets/3d80cc2f-28ae-4215-a302-22f7f0e6f191" />

Code in your favorite IDE with over 60 IDEs supported!

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

Comment out the `LOOPS_API_KEY` for the local letter opener, otherwise the app will try to send out a email and fail.

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
