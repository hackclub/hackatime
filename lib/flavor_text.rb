class FlavorText
  def self.same_user
    [
      "it u!",
      "it's yUwU",
      "uwu",
      "hey there",
      "look familiar?",
      "i'm seeing double!!",
      "you again?",
      "your twin?!",
      "despite everything, it's still you",
      "our favourite user!",
      "back again?",
      "someone you used to know!",
      "my favourite customer!"
    ]
  end

  def self.slack_loading_messages
    [
      ".split() === :large_blue_circle::large_green_circle::large_yellow_circle::large_orange_circle::red_circle::large_purple_circle:",
      "spinning the rgbs"
    ]
  end

  def self.loading_messages
    [
      "Generating leaderboard...",
      "Crunching the numbers...",
      "Hold tight, I'm working on it...",
      "chugging the data juice",
      "chugging *Stat-Cola©*, for those who want to know things™",
      "that's numberwang!",
      "crunching the numbers",
      "munching the numbers",
      "gurgling the bits",
      "juggling the electrons",
      "chomping the bytes",
      "playing the photons on bass",
      "reticulating the splines",
      "rolling down data hills",
      "frolicking through fields of numbers",
      "skiing the data slopes",
      "dropping in and sending it",
      "zooming through the cyber-pipes",
      "grabbing the stats",
      "switching the dependent and independent variables",
      "flipping a coin to choose which axis to use",
      "warming up the powerhouse of the cell",
      "calculating significant figures...",
      "calculating insignificant figures...",
      "p-hacking the n value",
      "computing P = NP",
      "realizing P ≠ NP",
      "so, uh... come here often?",
      "*powertool noises*",
      "*frantic typing noises*",
      "*keyboard clacking noises*",
      "*crunching number noises*",
      "*beep* *beep* *beep*",
      "carrying the one",
      "team-carrying the one",
      "carrying the zero",
      "AD carrying the one",
      "ganking the one before it gets carried",
      "spinning violently around the y-axis",
      "#{%w[tokenizing serializing stringifying].sample} #{[ "blood, sweat, & tears", "the human condition", "personal experiences", "elbow grease" ].sample}",
      "waking up the bits",
      "petting the bits",
      "testing patience",
      "[npm] now installing #{rand(3..7)} of #{rand(26_000..29_000)} packages",
      "Installing dependencies",
      "shoveling the overflowed pixels",
      "Are ya' winning, son?",
      "Dropkicking the cache into the sun",
      "[#{self.other_servers.sample}] starting on port #{self.common_ports.sample}",
      "compressing the accountants",
      "loading up TurboTax, time edition"
    ]
  end

  def self.common_ports
    %w[
      80
      443
      3000
      3001
      3002
    ]
  end

  def self.other_servers
    %w[
      express
      django
      flask
      ngrok
      nextjs
    ]
  end

  def self.other_languages
    %w[
      bash
      bunjs
      c
      c#
      c++
      go
      java
      javascript
      kotlin
      perl
      php
      python
      rust
      swift
    ]
  end

  def self.rare_loading_messages
    [
      "I would like to thank the academy...",
      "If you really think about it, isn't coffee just refried bean water?",
      "I'd be faster if I was written in #{self.other_languages.sample}",
      "Loading better loading messages..."
    ]
  end

  def self.compliment
    [
      "You're doing great!",
      "You're a star!",
      "Keep it up!",
      "No stopping you!",
      "You're crushing it!",
      "Look at you go!",
      "Absolute legend!",
      "You're on fire!",
      "Nailed it!",
      "Unstoppable!",
      "Way to go!",
      "You've got this!",
      "Smashing it!",
      "Total rockstar!",
      "Brilliant work!",
      "You're the best!",
      "Keep shining!",
      "Phenomenal!",
      "You're killing it!"
    ]
  end

  def self.rare_compliment
    [ "Don't let your dreams be memes!" ]
  end

  def self.motto
    [
      "track your time before it tracks you!",
      "it's the thought that counts.",
      "git #{%w[good gud].sample}.",
      "time flies when you git good!",
      "take your time!",
      "have your time and eat it too!",
      "give it some time!",
      "it's time to tiempo!",
      "take your time... or we will!",
      "have your time and eat it too!",
      "give it some time!",
      "take a time, leave a time!",
      "the only thing that can't be bought!",
      "everyone always asks how i'm doing, not when i'm doing.",
      "go forth and commit times!",
      "time you can count on!",
      "well, it's about time!",
      "like clocks but better",
      "just a second!",
      "loading jokes, just give me a sec!",
      "now you'll never need to second guess yourself",
      "better late than never",
      "beat the clock!",
      "only time will tell!",
      "it's of the essence!",
      "all in good time",
      "like turbotax for time!",
      "never a minute too soon",
      "a minute saved is a minute earned",
      "how did it get so late so soon?", # dr. seuss
      "You can have it all. Just not all at once.", # oprah i think?
      "from the #{%w[makers inventor].sample} of #{%w[clocks time hackatime].sample}",
      "#{%w[est created inited].sample} <span id='init-time-ago'>#{Time.now.to_i - Time.parse("Sun Feb 16 03:21:30 2025 -0500").to_i}</span> seconds ago!<script>setInterval(()=>{document.getElementById('init-time-ago').innerHTML=parseInt(document.getElementById('init-time-ago').innerHTML)+1},1000)</script>".html_safe,
      "uptime: <span id='uptime'>#{Time.now.to_i - Rails.application.config.server_start_time.to_i}</span> seconds!<script>setInterval(()=>{document.getElementById('uptime').innerHTML=parseInt(document.getElementById('uptime').innerHTML)+1},1000)</script>".html_safe,
      "It takes a long time to build something good: <a href='https://github.com/hackclub/hackatime#readme' target='_blank'><img src='https://hackatime-badge.hackclub.com/U0C7B14Q3/harbor'></a>".html_safe,
      "If you're seeing this, the page is currently <a href='https://uptime.hackclub.com/status/hackatime' target='_blank'><img src='https://uptime.hackclub.com/api/badge/4/status'></a>".html_safe,
      "time is money!",
      "in soviet russia, time tracks you!",
      "tick tock!",
      "it waits for no one!",
      "ticking away...",
      "working around the clock!"
    ]
  end

  def self.rare_motto
    [
      "i don't care what everyone else says, you're not that dumb",
      "<a href='https://github.com/hackclub/hackatime' target='_blank'>open source!</a>".html_safe,
      "kill time, don't let it kill you",
      "kill time, before it kills you",
      "better log it or the time man will come out at midnight and get you",
      "the best way to pay your time tax!",
      "you need to lock-in",
      "no time to explain, time is running out!"
    ]
  end

  def self.conditional_mottos(user)
    r = []

    r << "quit slacking off!" if user.slack_uid.present?
    r << "in the nick of time!" if %w[nick nicholas nickolas].include?(user.display_name)
    r << "just-in time!" if %w[justin justine].include?(user.display_name)

    minutes_logged = Cache::MinutesLoggedJob.perform_now
    r << "in the past hour, #{minutes_logged} minutes have passed" if minutes_logged > 0

    r
  end

  def self.latin_phrases
    [
      "carpe diem", # "seize the day"
      "nemo sine vitio est", # "no one is without fault"
      "docendo discimus", # "by teaching, we learn"
      "per aspera ad astra", # "through adversity to the stars"
      "ex nihilo nihil", # "from nothing, nothing"
      "aut viam inveniam aut faciam", # "i will either find a way or make one"
      "semper ad mellora", # "always towards better things"
      "soli fortes, una fortiores", # "strong alone, stronger together"
      "nulla tenaci invia est via", # "for the tenacious, no road is impassable"
      "nihil boni sine labore" # "nothing achieved without hard work"
    ]
  end
end
