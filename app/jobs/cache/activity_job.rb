class Cache::ActivityJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(total: 1, drop: true)

  def self.priority = 10

  def perform(force_reload: false)
    Rails.cache.write(cache_key, calculate, expires_in: cache_expiration) if force_reload
    Rails.cache.fetch(cache_key, expires_in: cache_expiration) { calculate }
  end

  private

  def cache_key = self.class.name.underscore
  def cache_expiration = 1.hour
  def calculate = raise(NotImplementedError, "You must implement #calculate in your job class")
end
