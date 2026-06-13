require "test_helper"

# Tests for User.fuzzy_ranked_search (UserFuzzySearch concern).
#
# Production scenarios mirror the queries the admin search UI fires:
#   "mahad", "miggy", "58", "mahadkalam1234@gmail.com", "mahadkalam1234", "json"
# — each of those is asserted against equivalent fixture users below.
#
# Invariants covered:
#   - blank/whitespace input -> none
#   - limit kwarg respected
#   - ordering: rank_score DESC, username ASC
#   - rank scoring tiers (id/slack_uid exact = 1000; field exact = 100;
#     prefix = 50; contains = 10; tiers compound additively)
#   - case-insensitive ILIKE on username/email fields
#   - case-sensitive equality on slack_uid
#   - matched_email picks best email (exact > prefix > contains > any)
#   - matched_email is nil only when the user has zero emails
#   - has_any_email correctly reflects email-row presence
#   - SQL-LIKE wildcards (%/_) in the term are escaped, not interpreted
class UserFuzzySearchTest < ActiveSupport::TestCase
  def create_user(attrs = {})
    User.create!({ timezone: "UTC" }.merge(attrs))
  end

  def with_email(user, email)
    user.email_addresses.create!(email: email)
    user
  end

  # ----- blank input -----

  test "returns none for blank term" do
    assert_equal [], User.fuzzy_ranked_search("").to_a
    assert_equal [], User.fuzzy_ranked_search(nil).to_a
    assert_equal [], User.fuzzy_ranked_search("   ").to_a
  end

  test "strips leading and trailing whitespace from term" do
    u = create_user(username: "spacecadet")
    with_email(u, "spacecadet@example.com")
    ids = User.fuzzy_ranked_search("  spacecadet  ").to_a.map(&:id)
    assert_includes ids, u.id
  end

  # ----- limit -----

  test "respects limit keyword arg" do
    5.times { |i| create_user(username: "limittest#{i}") }
    rows = User.fuzzy_ranked_search("limittest", limit: 3).to_a
    assert_equal 3, rows.size
  end

  test "default limit is 20" do
    25.times { |i| create_user(username: "manyusers#{i}") }
    rows = User.fuzzy_ranked_search("manyusers").to_a
    assert_equal 20, rows.size
  end

  # ----- ranking tiers -----

  test "exact id match scores 1000" do
    u = create_user(username: "exactiduser")
    row = User.fuzzy_ranked_search(u.id.to_s).first
    assert_equal u.id, row.id
    assert_operator row.rank_score, :>=, 1000
  end

  test "exact slack_uid match scores 1000" do
    u = create_user(slack_uid: "U#{SecureRandom.hex(8).upcase}", username: "slackuiduser")
    row = User.fuzzy_ranked_search(u.slack_uid).first
    assert_equal u.id, row.id
    assert_operator row.rank_score, :>=, 1000
  end

  test "slack_uid match is case-sensitive" do
    u = create_user(slack_uid: "U#{SecureRandom.hex(8).upcase}", username: "casesensitive_slack")
    downcased = u.slack_uid.downcase
    refute_equal u.slack_uid, downcased, "test fixture should contain uppercase letters"

    # downcased term should NOT hit the 1000-point slack_uid exact path
    rows = User.fuzzy_ranked_search(downcased).where(id: u.id)
    assert rows.empty? || rows.first.rank_score < 1000,
      "downcased slack_uid should not score 1000 (case-sensitive equality)"
  end

  test "exact username match scores 100" do
    u = create_user(username: "exactname")
    with_email(u, "exactname-#{SecureRandom.hex(4)}@example.com")
    row = User.fuzzy_ranked_search("exactname").find { |r| r.id == u.id }
    # exact (100) + email contains "exactname" (10) = 110, plus any other tiers
    assert_operator row.rank_score, :>=, 100
    assert_operator row.rank_score, :<, 1000
  end

  test "username prefix match scores 50" do
    u = create_user(username: "prefixmatch123")
    row = User.fuzzy_ranked_search("prefixmatch").find { |r| r.id == u.id }
    # prefix (50). May also have substring (10) trigger separately so >=50.
    assert_operator row.rank_score, :>=, 50
    assert_operator row.rank_score, :<, 100
  end

  test "username substring match scores 10" do
    u = create_user(username: "abcsubstringxyz")
    row = User.fuzzy_ranked_search("substring").find { |r| r.id == u.id }
    assert_operator row.rank_score, :>=, 10
    assert_operator row.rank_score, :<, 50
  end

  test "username matching is case-insensitive" do
    u = create_user(username: "MixedCaseUser")
    assert User.fuzzy_ranked_search("mixedcaseuser").any? { |r| r.id == u.id }
    assert User.fuzzy_ranked_search("MIXEDCASEUSER").any? { |r| r.id == u.id }
  end

  # ----- multi-field tiers -----

  test "github_username, slack_username, and email tiers contribute" do
    u = create_user(github_username: "githubmatch", slack_username: "slackmatch")
    with_email(u, "emailmatch@example.com")

    gh = User.fuzzy_ranked_search("githubmatch").find { |r| r.id == u.id }
    sl = User.fuzzy_ranked_search("slackmatch").find { |r| r.id == u.id }
    em = User.fuzzy_ranked_search("emailmatch@example.com").find { |r| r.id == u.id }
    assert_operator gh.rank_score, :>=, 100
    assert_operator sl.rank_score, :>=, 100
    assert_operator em.rank_score, :>=, 100
  end

  test "scores from multiple matching fields compound additively" do
    # Same term hits username exact + github_username prefix + email contains
    u = create_user(username: "compound", github_username: "compound_gh")
    with_email(u, "user@compound.example.com")
    row = User.fuzzy_ranked_search("compound").find { |r| r.id == u.id }
    # username exact (100) + github_username prefix (50) + email contains (10) >= 160
    assert_operator row.rank_score, :>=, 160
  end

  # ----- email matching tiers -----

  test "email exact match scores 100" do
    u = create_user(username: "emailexact_#{SecureRandom.hex(4)}")
    with_email(u, "exact@example.test")
    row = User.fuzzy_ranked_search("exact@example.test").find { |r| r.id == u.id }
    assert_operator row.rank_score, :>=, 100
    assert_equal "exact@example.test", row.matched_email
  end

  test "email prefix match scores 50" do
    u = create_user
    with_email(u, "prefixsearch@example.test")
    row = User.fuzzy_ranked_search("prefixsearch").find { |r| r.id == u.id }
    # Score must be >= 50 (prefix tier). May add up if other fields coincidentally match.
    assert_operator row.rank_score, :>=, 50
    assert_equal "prefixsearch@example.test", row.matched_email
  end

  test "email substring match scores 10" do
    u = create_user
    with_email(u, "foo-deepsubstring-bar@example.test")
    row = User.fuzzy_ranked_search("deepsubstring").find { |r| r.id == u.id }
    assert_operator row.rank_score, :>=, 10
    assert_equal "foo-deepsubstring-bar@example.test", row.matched_email
  end

  test "matched_email picks the best matching email when user has multiple" do
    u = create_user
    with_email(u, "nope@other.example.test")
    with_email(u, "exactmatch@best.example.test")
    with_email(u, "exactmatchprefixed@best.example.test") # prefix match
    row = User.fuzzy_ranked_search("exactmatch@best.example.test").find { |r| r.id == u.id }
    assert_equal "exactmatch@best.example.test", row.matched_email
  end

  test "matched_email falls back to any email when no email matches the term" do
    u = create_user(slack_uid: "U#{SecureRandom.hex(8).upcase}", username: "nonemailmatch")
    with_email(u, "completely-unrelated@example.test")
    row = User.fuzzy_ranked_search("nonemailmatch").find { |r| r.id == u.id }
    assert_equal "completely-unrelated@example.test", row.matched_email,
      "matched_email should fall back to any email so the controller's has_any_email gate works"
  end

  test "matched_email is nil when user has no emails" do
    u = create_user(slack_uid: "U#{SecureRandom.hex(8).upcase}", username: "noemailuser")
    row = User.fuzzy_ranked_search("noemailuser").find { |r| r.id == u.id }
    assert_nil row.matched_email
  end

  # ----- has_any_email -----

  test "has_any_email is true when user has at least one email" do
    u = create_user(username: "hasemail_#{SecureRandom.hex(4)}")
    with_email(u, "anything@example.test")
    row = User.fuzzy_ranked_search(u.username).find { |r| r.id == u.id }
    assert_equal true, ActiveModel::Type::Boolean.new.cast(row.has_any_email)
  end

  test "has_any_email is false when user has no emails" do
    u = create_user(slack_uid: "U#{SecureRandom.hex(8).upcase}", username: "noemails_#{SecureRandom.hex(4)}")
    row = User.fuzzy_ranked_search(u.username).find { |r| r.id == u.id }
    assert_equal false, ActiveModel::Type::Boolean.new.cast(row.has_any_email)
  end

  # ----- ordering -----

  test "results are ordered by rank_score DESC then username ASC" do
    # Highest rank: exact username match
    high = create_user(username: "orderingtest")
    # Mid rank: prefix match
    mid = create_user(username: "orderingtest_extra_a")
    # Same prefix-match score, alphabetically later username
    mid_b = create_user(username: "orderingtest_extra_b")
    rows = User.fuzzy_ranked_search("orderingtest").to_a
    ranks = rows.map(&:rank_score)
    assert_equal ranks.sort.reverse, ranks, "rank_score must be DESC"

    same_rank = rows.select { |r| r.id.in?([ mid.id, mid_b.id ]) }
    assert_equal [ mid.id, mid_b.id ], same_rank.map(&:id),
      "tie-breaking should fall back to username ASC"
    _ = high # silence unused warning; presence already implied by ordering
  end

  # ----- SQL safety -----

  test "term containing LIKE wildcards is escaped, not interpreted" do
    u = create_user(username: "literal_underscore")
    # `_` in LIKE normally matches any single character. Sanitized term should
    # only match the literal underscore, not e.g. "literalXunderscore".
    decoy = create_user(username: "literalXunderscore")
    rows = User.fuzzy_ranked_search("literal_underscore").to_a
    ids = rows.map(&:id)
    assert_includes ids, u.id
    refute_includes ids, decoy.id, "literal `_` must not be treated as LIKE wildcard"
  end

  test "term containing percent sign is escaped" do
    u = create_user(username: "literalpercent")
    create_user(username: "decoy_no_percent")
    rows = User.fuzzy_ranked_search("%").to_a
    ids = rows.map(&:id)
    refute_includes ids, u.id, "literal `%` must not match arbitrary substrings"
  end

  # ----- production-query parity -----

  test "production query 'mahad' returns the user with username mahad ranked highest" do
    mahad = create_user(username: "mahad", slack_uid: "U059VC0UDEU")
    with_email(mahad, "mahadkalam1234@gmail.com")
    create_user(username: "mahadmammu5") # secondary contains match
    row = User.fuzzy_ranked_search("mahad").first
    assert_equal mahad.id, row.id
    assert_operator row.rank_score, :>=, 100
  end

  test "production query 'miggy' returns the user whose slack_username is miggy" do
    miggy = create_user(username: "shy", slack_username: "miggy", github_username: "ImShyMike")
    with_email(miggy, "imshymike@proton.me")
    row = User.fuzzy_ranked_search("miggy").find { |r| r.id == miggy.id }
    assert row, "user matched by slack_username should appear"
    assert_operator row.rank_score, :>=, 100
  end

  test "production query '58' (numeric) hits the exact-id path" do
    u = create_user(username: "byid_#{SecureRandom.hex(4)}")
    row = User.fuzzy_ranked_search(u.id.to_s).find { |r| r.id == u.id }
    assert row, "numeric term should find user by id"
    assert_operator row.rank_score, :>=, 1000
  end

  test "production query 'mahadkalam1234@gmail.com' (full email) is an exact email match" do
    u = create_user(username: "mahad", slack_uid: "U#{SecureRandom.hex(8).upcase}")
    with_email(u, "mahadkalam1234@gmail.com")
    row = User.fuzzy_ranked_search("mahadkalam1234@gmail.com").find { |r| r.id == u.id }
    assert_equal "mahadkalam1234@gmail.com", row.matched_email
    # exact (100) + maybe other tiers for "mahad" inside the email containing username
    assert_operator row.rank_score, :>=, 100
  end

  test "production query 'mahadkalam1234' (email prefix) returns email prefix match" do
    u = create_user(slack_uid: "U#{SecureRandom.hex(8).upcase}")
    with_email(u, "mahadkalam1234@gmail.com")
    row = User.fuzzy_ranked_search("mahadkalam1234").find { |r| r.id == u.id }
    assert_equal "mahadkalam1234@gmail.com", row.matched_email
    # email prefix tier (50) at minimum
    assert_operator row.rank_score, :>=, 50
  end

  test "production query 'json' returns users with json in their username" do
    json_lk = create_user(username: "JSON_LK")
    with_email(json_lk, "sojyta@gmail.com")
    json_cam = create_user(username: "jsoncameron")
    with_email(json_cam, "jasoncameron.all@gmail.com")
    ids = User.fuzzy_ranked_search("json").to_a.map(&:id)
    assert_includes ids, json_lk.id
    assert_includes ids, json_cam.id
  end
end
