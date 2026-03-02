# Development

Hello and welcome to the Hackatime codebase! This is a brief guide to help you get started with contributing to the project.

## Quickstart

You'll need Docker installed on your machine. Follow the instructions [here](https://docs.docker.com/get-docker/) to install Docker. If you're on a Mac, you can use [OrbStack](https://orbstack.dev/) to run Docker natively.

Clone down the repository:

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

Start the containers:

```sh
$ docker compose up -d
$ docker compose exec web /bin/bash
```

We'll now setup the database. In your container shell, run the following:

```bash
app# bin/rails db:create db:schema:load db:seed
```

Now, let's start up the app!

```bash
app# bin/dev
```

Want to do other things?

```bash
app# bin/rails c # start an interactive irb!
app# bin/rails db:migrate # migrate the database
app# bin/rails rswag:specs:swaggerize # generate API documentation
```

You can now access the app at <http://localhost:3000/>, using the `test@example.com` email.

## Tests

When making a change, **add tests** to ensure that the change does not break existing functionality, as well as to ensure that the change works as expected. Additionally, run the tests to verify that the change has not introduced any new bugs:

```bash
bin/rails test
```

Please don't use mocks or stubs in your tests unless absolutely necessary. More often than not, these tests would end up testing _the mocks themselves_, rather than the actual code being tested.

Prefer using Capybara (browser) tests whenever possible, as this helps test both the frontend and backend of the application. You should also that your tests cover all possible edge cases and scenarios!

## Running CI locally

To run all CI checks locally, you can run:

```bash
docker compose exec web bin/ci
```

_Make sure these actually pass before making a PR!_

## Migrations

These can be used to modify the database schema. Don't modify `db/schema.rb` directly.

You also shouldn't create a migration file by hand. Instead, use the `bin/rails generate migration` command to generate a migration file.

**Ensure migrations do not lock the database!** This is super, super important.

## Jobs

Don't create a job file by hand. Instead, use the `bin/rails generate job` command to generate a job file.

Ensure jobs do not lock the database.
