class Admin::AdminApiKeysController < Admin::BaseController
  before_action :set_admin_api_key, only: [ :show ]
  before_action :set_own_admin_api_key, only: [ :destroy ]
  # Viewers are read-only and must not be able to mint or revoke admin API
  # keys (creation IS a write, and a viewer-owned key would let them call any
  # admin-API endpoint that doesn't have its own viewer guard).
  before_action -> { require_admin_level!(:admin, :superadmin) }, only: [ :new, :create, :destroy ]

  def index
    keys = AdminApiKey.includes(:user).active.order(created_at: :desc)
    render inertia: "Admin/AdminApiKeys/Index", props: {
      api_keys: keys.map { |key| serialize_key(key, created_at: key.created_at.strftime("%b %d, %Y at %I:%M %p")) },
      can_create_keys: current_user.admin_level.in?(%w[admin superadmin ultraadmin])
    }
  end

  def show
    show_token = session.delete(:newkey) == @admin_api_key.id
    render inertia: "Admin/AdminApiKeys/Show", props: {
      api_key: serialize_key(@admin_api_key, created_at: @admin_api_key.created_at.strftime("%B %d, %Y at %I:%M %p"),
        preview_length: 20, token: show_token ? @admin_api_key.token : nil),
      show_token: show_token
    }
  end

  def new
    @admin_api_key = current_user.admin_api_keys.build
    render_new
  end

  def create
    @admin_api_key = current_user.admin_api_keys.build(admin_api_key_params)

    if @admin_api_key.save
      session[:newkey] = @admin_api_key.id
      redirect_to admin_admin_api_key_path(@admin_api_key)
    else
      render_new(status: :unprocessable_entity)
    end
  end

  def destroy
    @admin_api_key.revoke!
    redirect_to admin_admin_api_keys_path, notice: "the key has been revoked"
  end

  private

  def render_new(status: :ok)
    render inertia: "Admin/AdminApiKeys/New", props: { errors: @admin_api_key.errors.full_messages }, status: status
  end

  def serialize_key(key, created_at:, preview_length: 12, token: nil)
    { id: key.id, name: key.name, token_preview: "#{key.token[0..preview_length]}...", token: token, created_at: created_at,
      user: { id: key.user.id, display_name: key.user.display_name, avatar_url: key.user.avatar_url } }
  end

  def set_admin_api_key
    @admin_api_key = AdminApiKey.find(params[:id])
  end

  def set_own_admin_api_key
    admin_api_keys = current_user.admin_level_ultraadmin? ? AdminApiKey : current_user.admin_api_keys
    @admin_api_key = admin_api_keys.find_by(id: params[:id])
    return if @admin_api_key
    redirect_to admin_admin_api_keys_path, alert: "You can only revoke your own admin API keys."
  end

  def admin_api_key_params
    params.require(:admin_api_key).permit(:name)
  end
end
