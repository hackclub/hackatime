class Cache::ActivityJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  # Shared by every calculation, including synchronous perform_now calls.
  # Privacy erasure takes this same advisory lock exclusively through commit.
  ERASURE_LOCK_KEY = 0x4841434B43414348

  good_job_control_concurrency_with(total_limit: 1)

  def self.priority = 10

  def perform(force_reload: false)
    ActiveRecord::Base.transaction do
      if ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_xact_lock_shared(#{ERASURE_LOCK_KEY})")
        Rails.cache.write(cache_key, calculate, expires_in: cache_expiration) if force_reload
        Rails.cache.fetch(cache_key, expires_in: cache_expiration) { calculate }
      else
        # Do not tie up request threads behind erasure, or publish a snapshot
        # that can still contain the account being erased. Only return it.
        calculate
      end
    end
  end

  private

  def cache_key = self.class.name.underscore
  def cache_expiration = 1.hour
  def calculate = raise(NotImplementedError, "You must implement #calculate in your job class")
end
