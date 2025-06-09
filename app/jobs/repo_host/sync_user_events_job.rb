require "http" # Make sure 'http' gem is available

module RepoHost
  class SyncUserEventsJob < ApplicationJob
    queue_as :literally_whenever

    # MAX_API_PAGES_TO_FETCH: Max pages to fetch. GitHub's /users/{username}/events endpoint
    # is limited to 300 events. If per_page=100 (as we request), this is 3 pages.
    # If GitHub defaults to per_page=30, this would be 10 pages.
    # This constant acts as a safeguard.
    MAX_API_PAGES_TO_FETCH = 10
    EVENTS_PER_PAGE = 100

    discard_on ActiveJob::DeserializationError # Standard GoodJob practice

    # Retry with exponential backoff for transient network issues or temporary API errors
    retry_on StandardError, wait: ->(executions) { [ executions * 5, 60 ].min.seconds }, attempts: 3

    def perform(user_id:, provider:)
      @user = User.find_by(id: user_id)
      @provider_sym = provider.to_sym

      unless @user
        Rails.logger.warn "RepoHost::SyncUserEventsJob: User ##{user_id} not found. Skipping."
        return
      end

      # Provider-specific setup
      case @provider_sym
      when :github
        unless @user.github_access_token.present? && @user.github_username.present?
          Rails.logger.warn "RepoHost::SyncUserEventsJob: User ##{@user.id} missing GitHub token or username. Skipping."
          return
        end
        Rails.logger.info "Starting GitHub event sync for User ##{@user.id} (#{@user.github_username})"
        process_github_events
      # Add :gitlab case here in the future
      # when :gitlab
      #   process_gitlab_events
      else
        Rails.logger.error "RepoHost::SyncUserEventsJob: Unknown provider '#{@provider_sym}' for User ##{@user.id}. Skipping."
        return
      end
      Rails.logger.info "Finished event sync for User ##{@user.id}, Provider: #{@provider_sym}."
    end

    private

    def process_github_events
      base_api_url = "https://api.github.com/users/#{@user.github_username}/events?per_page=#{EVENTS_PER_PAGE}"
      current_page = 1
      pages_processed_count = 0 # Renamed from page_count to avoid confusion with current_page
      newly_created_event_count_total = 0

      latest_stored_event_db_created_at = RepoHostEvent
                                        .where(user: @user, provider: @provider_sym)
                                        .maximum(:created_at)

      loop do
        pages_processed_count += 1
        if pages_processed_count > MAX_API_PAGES_TO_FETCH
          Rails.logger.warn "RepoHost::SyncUserEventsJob: Reached max pages (#{MAX_API_PAGES_TO_FETCH}) for User ##{@user.id}. Stopping."
          break
        end

        api_url = "#{base_api_url}&page=#{current_page}"
        Rails.logger.debug "Fetching GitHub events for User ##{@user.id}, Page #{current_page}, URL: #{api_url}"

        begin
          response = http_client_for_github.get(api_url)
        rescue HTTP::Error => e
          Rails.logger.error "RepoHost::SyncUserEventsJob: HTTP Error for User ##{@user.id} on page #{current_page}: #{e.message}"
          break
        end

        unless response.status.success?
          handle_github_api_error(response, current_page)
          break
        end

        fetched_events_json = response.parse
        Rails.logger.info "RepoHost::SyncUserEventsJob: User ##{@user.id}, Page #{current_page}: API returned #{fetched_events_json.size} events."
        break if fetched_events_json.empty?

        events_to_create_on_this_page = []
        stop_fetching_for_this_user = false

        fetched_events_json.each do |gh_event_data|
          original_event_id_str = gh_event_data["id"].to_s
          repo_host_event_id = RepoHostEvent.construct_event_id(@provider_sym, original_event_id_str)
          event_occurred_at = Time.zone.parse(gh_event_data["created_at"])

          if latest_stored_event_db_created_at && event_occurred_at <= latest_stored_event_db_created_at
            if RepoHostEvent.exists?(id: repo_host_event_id, user_id: @user.id)
              Rails.logger.info "RepoHost::SyncUserEventsJob: Event ID #{repo_host_event_id} (occurred at #{event_occurred_at}) already exists for User ##{@user.id}. Stopping pagination."
              stop_fetching_for_this_user = true
              break
            end
          end

          events_to_create_on_this_page << {
            id: repo_host_event_id,
            user_id: @user.id,
            raw_event_payload: gh_event_data,
            provider: RepoHostEvent.providers[@provider_sym],
            created_at: event_occurred_at,
            updated_at: Time.current
          }
        end

        if events_to_create_on_this_page.any?
          result = RepoHostEvent.import(
            events_to_create_on_this_page,
            on_duplicate_key_ignore: { conflict_target: [ :id ] },
            validate: false
          )
          newly_created_event_count_total += result.num_inserts
          Rails.logger.info "RepoHost::SyncUserEventsJob: For User ##{@user.id}, page #{current_page}: Processed #{events_to_create_on_this_page.size} events, imported #{result.num_inserts} new events."
        else
          Rails.logger.info "RepoHost::SyncUserEventsJob: For User ##{@user.id}, page #{current_page}: No new events to import."
        end

        break if stop_fetching_for_this_user

        # Manual pagination: increment page number for next request
        current_page += 1
        sleep 1 # Be a good API citizen; basic rate limit avoidance
      end # end of loop for pagination

      Rails.logger.info "RepoHost::SyncUserEventsJob: User ##{@user.id} GitHub sync: Imported a total of #{newly_created_event_count_total} new events across #{pages_processed_count} API pages."
    end

    def http_client_for_github
      HTTP.headers(
        "Accept" => "application/vnd.github+json",
        "Authorization" => "Bearer #{@user.github_access_token}",
        "X-GitHub-Api-Version" => "2022-11-28"
      ).timeout(connect: 5, read: 10) # Add timeouts
    end

    def handle_github_api_error(response, page_number)
      error_details = response.parse rescue response.body.to_s.truncate(255)
      log_message = "RepoHost::SyncUserEventsJob: GitHub API Error for User ##{@user.id} on page #{page_number}: Status #{response.status}, Body: #{error_details}"
      Rails.logger.error log_message

      case response.status.code
      when 401 # Unauthorized
        Rails.logger.warn "GitHub token for User ##{@user.id} is likely invalid or expired. Sync aborted."
      when 403 # Forbidden
        if response.headers["X-RateLimit-Remaining"].to_i == 0
          reset_time = Time.at(response.headers["X-RateLimit-Reset"].to_i)
          Rails.logger.warn "GitHub API rate limit exceeded for User ##{@user.id}. Resets at #{reset_time}. Sync aborted."
        else
          Rails.logger.warn "GitHub API permission issue for User ##{@user.id} (e.g. fine-grained token scopes). Sync aborted."
        end
      when 404 # Not Found
        Rails.logger.warn "GitHub user '#{@user.github_username}' (User ##{@user.id}) not found via API. Sync aborted."
      when 422 # Unprocessable Entity - often if the user has been suspended
        Rails.logger.warn "GitHub API returned 422 for User ##{@user.id}. User might be suspended. Sync aborted. Details: #{error_details}"
      else
        Rails.logger.error "Unhandled GitHub API error for User ##{@user.id}: #{response.status}. Sync aborted."
      end
    end
  end
end
