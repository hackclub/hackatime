# frozen_string_literal: true

class OauthApplicationPageProps
  FORM_METADATA = {
    new: { title_key: "doorkeeper.applications.new.title",
           subheading: "Create a new OAuth application to integrate with Hackatime.",
           form_mode: "new", form_method: "post" },
    edit: { title_key: "doorkeeper.applications.edit.title",
            subheading_template: "Update the settings for %{name}.",
            form_mode: "edit", form_method: "patch" }
  }.freeze

  def initialize(application, admin_mode: false, actor: nil, can_assign_admin_scope: false)
    @application = application
    @admin_mode = admin_mode
    @actor = actor
    @can_assign_admin_scope = can_assign_admin_scope
  end

  def summary
    props = {
      id: application.id,
      name: application.name,
      verified: application.verified?,
      confidential: application.confidential?,
      scopes: application.scopes.to_a.map(&:to_s),
      redirect_uris: redirect_uris
    }
    return props unless admin_mode

    props.merge(
      created_at: application.created_at.strftime("%b %d, %Y"),
      owner: owner_summary
    )
  end

  def show(secret:, can_toggle_verified:)
    {
      page_title: admin_mode ? "#{application.name} - Admin OAuth Application" : "#{application.name} - OAuth Application",
      heading: admin_mode ? application.name : I18n.t("doorkeeper.applications.show.title", name: application.name),
      subheading: admin_mode ? "Admin view of OAuth application credentials and settings." : "OAuth application credentials and settings.",
      admin_mode: admin_mode,
      application: show_application(can_toggle_verified: can_toggle_verified),
      secret: {
        value: secret,
        hashed: secret.blank? && Doorkeeper.config.application_secret_hashed?,
        just_rotated: secret.present?
      },
      labels: show_labels,
      confirmations: {
        rotate_secret: admin_mode ?
          "Are you sure? This will invalidate the current client secret and break existing integrations." :
          "Are you sure? This will invalidate your current secrets and break existing integrations."
      }
    }
  end

  def form(action:)
    meta = FORM_METADATA.fetch(action)
    heading = admin_mode ? "Edit application" : I18n.t(meta[:title_key])
    subheading = meta[:subheading] || format(meta[:subheading_template], name: application.name)

    {
      page_title: admin_mode ? "Edit #{application.name} - Admin" : heading,
      heading: heading,
      subheading: subheading,
      admin_mode: admin_mode,
      form_mode: meta[:form_mode],
      form_method: meta[:form_method],
      labels: {
        submit: admin_mode ? "Save changes" : I18n.t("doorkeeper.applications.buttons.submit"),
        cancel: I18n.t("doorkeeper.applications.buttons.cancel")
      },
      help_text: %i[redirect_uri blank_redirect_uri confidential]
                   .index_with { |key| I18n.t("doorkeeper.applications.help.#{key}") },
      allow_blank_redirect_uri: Doorkeeper.configuration.allow_blank_redirect_uri?(application),
      application: form_application,
      scope_options: scope_options,
      errors: form_errors
    }
  end

  private

  attr_reader :application, :admin_mode, :actor, :can_assign_admin_scope

  def show_application(can_toggle_verified:)
    props = summary.merge(
      uid: application.uid,
      redirect_to_hca_login: application.redirect_to_hca_login?,
      can_toggle_verified: can_toggle_verified
    )
    return props unless admin_mode

    props.merge(
      created_at: application.created_at.strftime("%B %d, %Y at %I:%M %p"),
      owner: owner_details
    )
  end

  def form_application
    {
      id: application.id,
      persisted: application.persisted?,
      name: application.name.to_s,
      redirect_uri: application.redirect_uri.to_s,
      confidential: application.confidential?,
      redirect_to_hca_login: application.redirect_to_hca_login?,
      verified: application.verified?,
      selected_scopes: selected_scopes
    }
  end

  def form_errors
    {
      full_messages: application.errors.full_messages,
      name: application.errors[:name],
      redirect_uri: application.errors[:redirect_uri],
      scopes: application.errors[:scopes],
      confidential: application.errors[:confidential]
    }
  end

  def selected_scopes
    scopes = application.scopes.to_a.map(&:to_s)
    return scopes if scopes.any? || application.persisted?

    Doorkeeper.configuration.default_scopes.to_a.map(&:to_s)
  end

  def scope_options
    default_scopes = Doorkeeper.configuration.default_scopes.to_a.map(&:to_s)
    optional_scopes = Doorkeeper.configuration.optional_scopes.to_a.map(&:to_s)
    optional_scopes -= [ OauthApplication::ADMIN_SCOPE ] unless can_assign_admin_scope

    (default_scopes + optional_scopes).uniq.map { |scope|
      { value: scope,
        description: I18n.t(scope, scope: %i[doorkeeper scopes], default: scope.humanize),
        default: default_scopes.include?(scope) }
    }
  end

  def show_labels
    %i[application_id secret secret_hashed scopes confidential callback_urls actions not_defined]
      .index_with { |key| I18n.t("doorkeeper.applications.show.#{key}") }
  end

  def redirect_uris = application.redirect_uri.to_s.split

  def owner_summary
    owner = application.owner
    owner && { id: owner.id, display_name: owner.display_name }
  end

  def owner_details
    owner = application.owner
    owner && { id: owner.id, display_name: owner.display_name, avatar_url: owner.avatar_url,
               can_impersonate: actor.can_impersonate?(owner) }
  end
end
