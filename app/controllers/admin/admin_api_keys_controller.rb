class Admin::AdminApiKeysController < Admin::BaseController
  before_action :set_admin_api_key, only: [ :show, :destroy ]

  def index
    @admin_api_keys = AdminApiKey.includes(:user).active.order(created_at: :desc)
  end

  def show
  end

  def new
    @admin_api_key = current_user.admin_api_keys.build
  end

  def create
    @admin_api_key = current_user.admin_api_keys.build(admin_api_key_params)

    if @admin_api_key.save
      flash[:notice] = "created! now go have fun with it"
      flash[:api_key_token] = @admin_api_key.token
      redirect_to admin_admin_api_key_path(@admin_api_key)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @admin_api_key.revoke!
    redirect_to admin_admin_api_keys_path, notice: "the key has been revoked"
  end

  private

  def set_admin_api_key
    @admin_api_key = AdminApiKey.find(params[:id])
  end

  def admin_api_key_params
    params.require(:admin_api_key).permit(:name)
  end
end
