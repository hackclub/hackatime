<!-- Why comment a markdown README you might ask? I don't know to be honest. I guess I'm a little bored :b -->

<img width="3504" height="2240" alt="Free, Open-Source Code Tracker" src="https://github.com/user-attachments/assets/8689e4a8-13f5-4b83-ae8c-b10b6db9c50c" /> <!-- Header -->


<!-- Header text -->
<div align="center">
  
# **Hackatime**

[![Ping](https://uptime.hackclub.com/api/badge/4/ping)](https://uptime.hackclub.com/status/hackatime)
[![Status](https://uptime.hackclub.com/api/badge/4/status)](https://uptime.hackclub.com/status/hackatime)
[![Work time](https://hackatime-badge.hackclub.com/U0C7B14Q3/harbor)](https://hackatime-badge.hackclub.com)

[**Documentation**](https://hackatime.hackclub.com/docs)

</div>

<!-- Main Content -->
**[Hackatime](https://hackatime.hackclub.com)** allows you to track the time you code, see daily and weekly coding leaderboards, and get statistics on projects, languages, and more.

<!-- IDES -->
<img width="3504" height="2240" alt="A visual of some of the supported IDEs" src="https://github.com/user-attachments/assets/3d80cc2f-28ae-4215-a302-22f7f0e6f191" />

**Code in your favorite IDE with over 60 IDEs supported!**

<!-- Statistics -->
<img width="3504" height="2240" alt="showcase of statistics" src="https://github.com/user-attachments/assets/e03a6b8a-fe19-44ad-8d70-c6ff246b0420" />

**Get detailed statistics by language, project, date, and more!**

---

<!-- Help -->

<div align="center"> 
  
  *Having issues? Reach out on the _#hackatime-help_ channel on [slack!](https://slack.hackclub.com/)* 
  
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

Comment out the `LOOPS_API_KEY` for the local letter opener, otherwise the app will try to send out a email and fail.

</div>

## Local development

Please read [DEVELOPMENT.md](DEVELOPMENT.md) for instructions on setting up and running the project locally.
