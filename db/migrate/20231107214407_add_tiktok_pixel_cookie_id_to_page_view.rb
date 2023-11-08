class AddTiktokPixelCookieIdToPageView < ActiveRecord::Migration[7.0]
  def change
    add_column "#{Land.config.schema}.pageviews", :tiktok_pixel_cookie_id, :text
  end
end
