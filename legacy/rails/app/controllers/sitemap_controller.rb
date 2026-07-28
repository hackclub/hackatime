class SitemapController < ApplicationController
  def sitemap
    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end
