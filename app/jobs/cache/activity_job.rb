class Cache::ActivityJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total: 1,
    drop: true
  )

  def self.priority
    10
  end

  def perform(force_reload: false)
    key = cache_key
    expiration = cache_expiration
    Rails.cache.write(key, calculate, expires_in: expiration) if force_reload

    Rails.cache.fetch(key, expires_in: expiration) do
      calculate
    end
  end

  private

  def cache_key
    self.class.name.underscore
  end

  def cache_expiration
    1.hour
  end

  def calculate
    raise NotImplementedError, "You must implement #calculate in your job class"
  end
end
