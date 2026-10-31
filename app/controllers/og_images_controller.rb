class OgImagesController < ApplicationController
  def show
    page = OgPage.find(params[:page])
    return head :not_found if page.nil?

    send_og_image PageOgImageGenerator.new(
      headline: page.headline, description: page.description, path: page.path, background: page.background
    )
  end
end
