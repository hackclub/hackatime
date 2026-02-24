class AttemptProjectRepoMappingJob < ApplicationJob
  queue_as :latency_10s
  include HasEnqueueControl

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "attempt_project_repo_mapping_job_#{arguments.first}_#{arguments.last}" },
    drop: true
  )

  def perform(user_id, project_name)
    @user = User.find(user_id)

    return unless @user.github_uid.present?
    return unless @user.github_username.present?
    return if @user.project_repo_mappings.exists?(project_name: project_name)
    return if ProjectRepoMapping::IGNORED_PROJECTS.include?(project_name)

    # Search for the project on GitHub
    repo_url = search_for_repo(@user.github_username, project_name)
    if repo_url.present?
      puts "creating mapping"
      create_mapping(project_name, repo_url)
      return
    end

    # now search for orgs the user is a member of & check in those places for the repo
    list_orgs.each do |org|
      repo_url = search_for_repo(org["login"], project_name)
      if repo_url.present?
        create_mapping(project_name, repo_url)
        return
      end
    end
  end

  private

  def create_mapping(project_name, repo_url)
    @user.project_repo_mappings.create!(project_name: project_name, repo_url: repo_url)
  end

  def search_for_repo(org_name, project_name)
    puts "Searching for repo #{project_name} in user #{org_name}"
    response = HTTP.auth("Bearer #{@user.github_access_token}")
      .get("https://api.github.com/repos/#{org_name}/#{project_name}")

    while response.status.moved_permanently?
      # when the repo is transferred/renamed, we get a redirect to follow
      sleep 1
      response = HTTP.auth("Bearer #{@user.github_access_token}")
        .get(response.headers["Location"])
    end

    return nil unless response.status.success?

    body = response.body.to_s
    Rails.logger.info "GitHub repo response for #{org_name}/#{project_name}: #{body.truncate(500)}"
    return nil if body.blank?

    repo = JSON.parse(body)
    puts "repo: #{repo}"
    repo["html_url"]
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse GitHub repo response: #{e.message}"
    nil
  end

  def list_orgs
    response = HTTP.auth("Bearer #{@user.github_access_token}")
      .get("https://api.github.com/users/#{@user.github_username}/orgs")

    Rails.logger.info "GitHub orgs response: #{response.body}"

    return [] unless response.status.success?

    parsed_response = JSON.parse(response.body)
    return [] unless parsed_response.is_a?(Array)

    parsed_response
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse GitHub orgs response: #{e.message}"
    []
  end
end
