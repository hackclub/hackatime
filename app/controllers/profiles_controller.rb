class ProfilesController < InertiaController
  layout "inertia"

  before_action :find_user

  SOCIAL_LINKS = [
    [ :github,   "GitHub",   :profile_github_url ],
    [ :twitter,  "Twitter",  :profile_twitter_url ],
    [ :bluesky,  "Bluesky",  :profile_bluesky_url ],
    [ :linkedin, "LinkedIn", :profile_linkedin_url ],
    [ :discord,  "Discord",  :profile_discord_url ],
    [ :website,  "Website",  :profile_website_url ]
  ].freeze

  def show
    return render_profile_not_found if @user.nil?

    @is_own_profile = current_user.present? && current_user.id == @user.id
    @profile_visible = @user.allow_public_stats_lookup || @is_own_profile
    set_profile_social_preview

    render inertia: "Profiles/Show", props: profile_props
  end

  def og_image
    return head :not_found if @user.nil?

    generated = ensure_profile_og_image!
    blob = @user.profile_og_image.blob
    etag = generated&.fingerprint || blob.metadata["fingerprint"] || blob.checksum

    expires_in 1.hour, public: true
    if stale?(etag: etag, last_modified: blob.created_at, public: true)
      png = generated&.png || @user.profile_og_image.download
      filename = generated&.filename || blob.filename.to_s
      send_data png, filename: filename, type: "image/png", disposition: "inline"
    end
  end

  def project
    return head :not_found if @user.nil?

    project_name = CGI.unescape(params[:project_name])
    mapping = @user.project_repo_mappings.find_by(project_name: project_name)
    return head :not_found unless mapping&.public_shared_at.present?

    h = ApplicationController.helpers
    hb = @user.heartbeats.where(project: project_name)
    stats = ProjectStatsService.new(hb).call
    first_heartbeat = hb.minimum(:time)
    since_date = first_heartbeat ? Time.at(first_heartbeat).to_date.strftime("%-m/%-d/%Y") : nil

    render inertia: "Projects/PublicShow", props: {
      page_title: "#{project_name} — @#{@user.username} | Hackatime",
      project_name: project_name, username: @user.username,
      since_date: since_date, repo_url: mapping.repo_url,
      total_time_label: h.short_time_detailed(stats[:total_time]),
      file_count: stats[:file_count],
      language_stats: stats[:language_stats],
      language_colors: stats[:language_colors],
      file_stats: stats[:file_stats], branch_stats: stats[:branch_stats]
    }
  end

  private

  def render_profile_not_found
    render inertia: "Errors/NotFound", props: {
      status_code: 404, title: "Page Not Found",
      message: "The profile you were looking for doesn't exist."
    }, status: :not_found
  end

  def find_user = @user = User.find_by(username: params[:username])

  def profile_props
    { page_title: profile_page_title, profile_visible: @profile_visible,
      is_own_profile: @is_own_profile, profile: profile_summary_payload,
      dashboard_stats: (@profile_visible ? ProfileStatsService.new(@user).dashboard_stats : nil) }
  end

  def profile_page_title
    "#{@user.username.present? ? "@#{@user.username}" : @user.display_name} | Hackatime"
  end

  def set_profile_social_preview
    @social_preview = true
    @page_title = @og_title = @twitter_title = profile_page_title
    @og_description = @twitter_description = profile_social_description
    @og_image = @twitter_image = profile_og_image_url(username: @user.username)
  end

  def profile_social_description
    return @user.profile_bio.to_s.squish.truncate(180) if @user.profile_bio.present?
    "View #{@user.display_name}'s Hackatime coding profile."
  end

  def ensure_profile_og_image!
    stats = public_profile_og_stats
    heatmap = public_profile_og_heatmap
    stats_status = if !@user.allow_public_stats_lookup then :private
    elsif stats.blank? then :not_computed
    else :available
    end

    generator = ProfileOgImageGenerator.new(@user, stats: stats, heatmap: heatmap, stats_status: stats_status)
    return nil if @user.profile_og_image.attached? && @user.profile_og_image.blob.metadata["fingerprint"] == generator.fingerprint

    result = generator.call
    previous_attachment = @user.profile_og_image.attachment if @user.profile_og_image.attached?
    @user.profile_og_image.attach(
      io: StringIO.new(result.png),
      filename: result.filename, content_type: "image/png",
      metadata: { fingerprint: result.fingerprint }
    )
    previous_attachment&.purge_later
    result
  end

  def public_profile_og_stats
    return nil unless @user.allow_public_stats_lookup
    stats = ProfileStatsService.new(@user).og_stats
    return nil if stats.blank?

    h = ApplicationController.helpers
    top_language = stats[:top_language]
    { all_label: h.short_time_simple(stats[:total_time_all]),
      week_label: h.short_time_simple(stats[:total_time_week]),
      streak_label: "#{@user.streak_days}d",
      top_language_label: (top_language.present? ? h.display_language_name(top_language).truncate(14) : "None") }
  end

  def public_profile_og_heatmap
    return nil unless @user.allow_public_stats_lookup

    rollup = DashboardRollup.find_by(user_id: @user.id, dimension: DashboardRollup::ACTIVITY_GRAPH_DIMENSION)
    duration_by_date = rollup&.payload&.fetch("duration_by_date", nil)
    return nil if duration_by_date.blank?

    duration_by_date.each_with_object({}) do |(date, seconds), out|
      key = (date.is_a?(Date) ? date.iso8601 : date.to_date.iso8601 rescue date.to_s)
      out[key] = seconds.to_i
    end
  end

  def profile_summary_payload
    { display_name: @user.display_name,
      username: @user.username || "", avatar_url: @user.avatar_url,
      trust_level: @user.public_trust_level, bio: @user.profile_bio,
      social_links: profile_social_links, github_profile_url: @user.github_profile_url,
      github_username: @user.github_username,
      streak_days: (@profile_visible ? @user.streak_days : nil) }
  end

  def profile_social_links
    SOCIAL_LINKS.filter_map do |key, label, url_attr|
      url = @user.public_send(url_attr)
      { key: key.to_s, label: label, url: url } if url.present?
    end
  end
end
