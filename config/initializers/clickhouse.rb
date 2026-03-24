module ClickhouseActiverecord
  class Settings
    # The app reads freshly written heartbeats immediately for stats, caches, and tests.
    # Use synchronous inserts so subsequent queries see the rows deterministically.
    def insert_settings
      { wait_for_async_insert: 1, async_insert: 0 }
    end
  end
end
