# Serves a profile photo (ProfilePhoto) to signed-in users. Links carry the
# photo's version (?v=), so the browser keeps it until it changes.
class ProfilePhotosController < ApplicationController
  def show
    photo = authorize ProfilePhoto.find(params[:id])
    expires_in 1.year, public: false if params[:v] == photo.version.to_s
    send_data photo.data, type: photo.content_type, disposition: "inline", filename: "foto"
  end
end
