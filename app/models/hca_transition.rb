# The four-week move to Hack Club sign-in only, counted from the deploy of
# the link flow (#1810). Slack and email sign-in keep working throughout.
module HCATransition
  STARTED_AT = Time.utc(2026, 11, 13, 12, 21)

  # Weeks one and two: a legacy sign-in is asked to link and may say "Not now".
  # Adults with no Slack account cannot create a Hack Club account from
  # Hackatime yet, so nobody is made to link before they can.
  SKIPPABLE_UNTIL = STARTED_AT + 2.weeks

  # Final week: every unlinked session is asked, however it signed in.
  REQUIRED_FOR_EVERY_SESSION_FROM = STARTED_AT + 3.weeks

  def self.skippable? = Time.current < SKIPPABLE_UNTIL

  def self.required_for_every_session? = Time.current >= REQUIRED_FOR_EVERY_SESSION_FROM
end
