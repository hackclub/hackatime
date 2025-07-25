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
      "despite everything, it's still you"
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
      "No stopping you!"
    ]
  end

  def self.rare_compliment
    [ "Don't let your dreams be memes!" ]
  end

  def self.random_time_video
    # these are just random videos/memes on youtube that have time in the title.
    # your milage may vary.
    [
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/d20a0673d3816509809ec028d02907c28c7926f7_it_s_pizza_time_at_new_years__lug5nf47wr4_.mp4",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/5836f8e156b985df9399467b1d2c642d2e2b7d48_dog_jumping_off_a_cliff_to_work_this_time_by_king_gizzard_and_the_lizard_wizard__2sp8-g61kpi_.mp4",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/8314bea9ee0a03e692ff7d52a68aa55880bebd75_it_s_time_to_kick_gum__gnvag2nwaug_.webm",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/85aa18933d81e3858caa3af5223fa7a651e9916f_this_time_he_can_sit_in_the_canoe_for_up_to_an_hour.__spc_2dxjbnw_.webm",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/ee015eb5e8a0bc58b9ded2d2aba57c55131c490a____cantina_theme____played_by_a_pencil_and_a_girl_with_too_much_time_on_her_hands__jcghl0lbdsk_.mp4",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/19f83326fae797d45aaf0ea58d7ed656704a2796_man_takes_a_photo_of_himself_30_times_a_second_every_second_for_12_seconds__gqgqjcijcty_.webm",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/7230a977c72609e88d38bc75ae293a5c217f520b_it_s_hamtaro_time__7hpp7pullwg_.webm",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/5108691fcfe1ae6939849e01f4474a1d55e9ee77_the_best_chess_handshake_of_all_time__chessbaseindia__tif2vt8s8p8_.webm",
      "https://www.youtube.com/watch?v=lMUSyvTBokc",
      "https://www.youtube.com/watch?v=wH4QsKQPYKQ&t=30s",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/125740ef06dac1b3a32d9d2c453d8c81bddd7fdb_stop-measuring-time-v0-1n64qvw0xfpa1.webp",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/1112c1e28e3a017738d1c4db1a18e292651fc49d_ey3jskc8brp11.webp",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/0bea6b9ea2f2d1a4a2bcb34f4763c390ea5d7672_1fagap51epelkfjtbs0ioh0ax116ed5_djuufhyvpie.webp",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/b35fd20790ab01c9f8400efaf454a21337a7f51e_8o4i3olrnqpy.webp",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/f9a9607e54bc4930fcfefd1f6541e81337ff338f_the_sound_of_a_dozen_clocks_out_of_sync__loud___gpigswnscqa_.mp4",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/a63ee6882e391a7e7e6affb4dc5818ec207ac4f2_bean_clock__jhd3o7owkbi_.mp4",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/cf5f3a38510d67d7f494ff706c08db8df03b554f_12_34_56__8rzn02qhbhc_.mp4",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/fe9daf4289985d6eb4194259623aec3f1ca3550d_clock.mp4__olqqe-7xjtm_.webm",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/8221a4b09a64822058338952fc55bdcdf295ccb0_curtis_leszczynski_eating_a_clock__fssk0b_b8x0_.mp4",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/88ad8245ed9c07ab61d00dcac7a3d78b4550e205_it_s_gonna_be_2_00_o_clock_watch_this__cq_fbs5gpcq_.webm",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/873ec323b4a8e5dd7caaa0bc34880dbf99299ae7_it_s_time_o_clock__kvfrybwub8a_.webm",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/1a28712d0c864563075eda92a60452555cb21a38____clocks____played_with_clocks__coldplay_cover___bjsox9dpw4e_.mp4",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/4e885cbf3e599e4b325ab16a2024d2907f7df09f_doctor_who_-_blink_-_big_ball_of_wibbly_wobbly..._time-y_wimey..._stuff.__q2nnzno_xps_.mp4"
    ]
  end

  def self.dino_meme_videos
    [
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/4154af08cda2835006529a36afc36b9dcc06d63e_untitled15_ezgif_com_crop_v1__1_.mp4",
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/575e6cd9fc079117a34b97cd93b671f92dbe06c6_get-dinoed.mp4"
    ]
  end

  def self.obvious
    [
      "obv.",
      "duh",
      "clearly"
    ]
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
      "written in #{Rails.application.config.lines_of_code} lines of code!",
      "#{%w[est created inited].sample} <span id='init-time-ago'>#{Time.now.to_i - Time.parse("Sun Feb 16 03:21:30 2025 -0500").to_i}</span> seconds ago!<script>setInterval(()=>{document.getElementById('init-time-ago').innerHTML=parseInt(document.getElementById('init-time-ago').innerHTML)+1},1000)</script>".html_safe,
      "uptime: <span id='uptime'>#{Time.now.to_i - Rails.application.config.server_start_time.to_i}</span> seconds!<script>setInterval(()=>{document.getElementById('uptime').innerHTML=parseInt(document.getElementById('uptime').innerHTML)+1},1000)</script>".html_safe,
      "It takes a long time to build something good: <a href='https://github.com/hackclub/hackatime#readme' target='_blank'><img src='https://hackatime-badge.hackclub.com/U0C7B14Q3/harbor'></a>".html_safe,
      "If you're seeing this, the page is currently <a href='https://status.hackatime.hackclub.com/status/hackatime' target='_blank'><img src='https://status.hackatime.hackclub.com/api/badge/1/status'></a>".html_safe,
      "time is money!",
      "in soviet russia, time tracks you!",
      "tick tock!",
      "it waits for no one!",
      "waiting for no one!"
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
    r << "in the nick of time!" if %w[nick nicholas nickolas].include?(user.username)
    r << "just-in time!" if %w[justin justine].include?(user.username)

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
