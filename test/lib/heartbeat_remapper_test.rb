require "test_helper"

class HeartbeatRemapperTest < ActiveSupport::TestCase
  class FirstRule
    ID = "test/first/v1"
    WRITABLE_FIELDS = %i[language].freeze

    def self.call(_attributes) = { language: "First" }
  end

  class SecondRule
    ID = "test/second/v1"
    WRITABLE_FIELDS = %i[language].freeze

    def self.call(attributes) = { language: "#{attributes[:language]} Second" }
  end

  test "rules run in registry order without mutating the input" do
    attributes = { entity: "file.txt", language: "Original", dependencies: [ "rack" ] }

    result = HeartbeatRemapper.call(attributes, registry: [ FirstRule, SecondRule ].freeze)

    assert_equal "First Second", result.attributes[:language]
    assert_equal %w[test/first/v1 test/second/v1], result.rule_ids
    assert_equal({ entity: "file.txt", language: "Original", dependencies: [ "rack" ] }, attributes)
  end

  test "rules cannot declare protected fields writable" do
    rule = Class.new do
      const_set(:ID, "test/protected/v1")
      const_set(:WRITABLE_FIELDS, %i[user_id].freeze)
      define_singleton_method(:call) { |_attributes| { user_id: 2 } }
    end

    assert_raises(HeartbeatRemapper::InvalidRule) do
      HeartbeatRemapper.call({ user_id: 1 }, registry: [ rule ])
    end
  end

  test "rules cannot change undeclared fields" do
    rule = Class.new do
      const_set(:ID, "test/undeclared/v1")
      const_set(:WRITABLE_FIELDS, %i[language].freeze)
      define_singleton_method(:call) { |_attributes| { entity: "other.rb" } }
    end

    assert_raises(HeartbeatRemapper::InvalidRule) do
      HeartbeatRemapper.call({ entity: "main.rb" }, registry: [ rule ])
    end
  end

  test "production rules are idempotent and report only effective changes" do
    first = HeartbeatRemapper.call({ entity: "/app/main.luau", language: "Lua" })
    second = HeartbeatRemapper.call(first.attributes)

    assert_equal "Luau", first.attributes[:language]
    assert_equal [ "language/authoritative-extension/v1" ], first.rule_ids
    assert_equal first.attributes, second.attributes
    assert_empty second.rule_ids
  end

  test "authoritative filenames use the language catalogue" do
    assert_equal "Dotenv", HeartbeatRemapper.call({ entity: "/app/.env.local", language: "Ezhil" }).attributes[:language]
    assert_equal "Ignore List", HeartbeatRemapper.call({ entity: "/app/.gitignore", language: "Ezhil" }).attributes[:language]
    assert_equal "Ignore List", HeartbeatRemapper.call({ entity: "/app/.prettierignore", language: "Text" }).attributes[:language]
    assert_equal "Option List", HeartbeatRemapper.call({ entity: "/app/.rspec", language: "Ezhil" }).attributes[:language]
    assert_equal "Git Attributes", HeartbeatRemapper.call({ entity: "/app/.gitattributes", language: "Ezhil" }).attributes[:language]
  end

  test "authoritative extensions correct deterministic content guessing failures" do
    assert_equal "JavaScript", HeartbeatRemapper.call({ entity: "/app/config.cjs", language: "Ezhil" }).attributes[:language]
    assert_equal "Jinja", HeartbeatRemapper.call({ entity: "/app/page.jinja", language: "XML" }).attributes[:language]
    assert_equal "PostCSS", HeartbeatRemapper.call({ entity: "/app/styles.postcss", language: "Ezhil" }).attributes[:language]
  end

  test "auto-detected file types use the language catalogue or Unknown" do
    detected = HeartbeatRemapper.call({ entity: "/app/main.rb", language: "AUTO_DETECTED" })
    unknown = HeartbeatRemapper.call({ entity: "/app/README.unrecognised", language: "AUTO_DETECTED" })
    ambiguous_json = HeartbeatRemapper.call({ entity: "/app/package.json", language: "AUTO_DETECTED" })
    ambiguous_rust = HeartbeatRemapper.call({ entity: "/app/main.rs", language: "AUTO_DETECTED" })

    assert_equal "Ruby", detected.attributes[:language]
    assert_equal [ "language/auto-detected/v1" ], detected.rule_ids
    assert_equal "Unknown", unknown.attributes[:language]
    assert_equal [ "language/auto-detected/v1" ], unknown.rule_ids
    assert_equal "Unknown", ambiguous_json.attributes[:language]
    assert_equal [ "language/auto-detected/v1" ], ambiguous_json.rule_ids
    assert_equal "Unknown", ambiguous_rust.attributes[:language]
    assert_equal [ "language/auto-detected/v1" ], ambiguous_rust.rule_ids
  end

  test "genuine Ezhil is preserved" do
    result = HeartbeatRemapper.call({ entity: "/app/program.n", language: "Ezhil" })

    assert_equal "Ezhil", result.attributes[:language]
    assert_empty result.rule_ids
  end
end
