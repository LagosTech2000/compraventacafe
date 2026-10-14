# A profile photo (ProfilePhoto) for people and users (Fernando, 2026-10-13).
# The form sends `photo` (an uploaded file) and `remove_photo`; the photo is
# saved with the record, or not at all.
module HasPhoto
  extend ActiveSupport::Concern

  included do
    has_one :photo, class_name: "ProfilePhoto", as: :owner, dependent: :destroy, autosave: true
    # The photo without its bytes, to show it (preload it in lists).
    has_one :photo_info, -> { select(ProfilePhoto.column_names - %w[data]) }, class_name: "ProfilePhoto", as: :owner

    attr_reader :photo_upload, :remove_photo

    validate :photo_upload_is_an_image
  end

  # The file the form sent (the browser already shrank it).
  def photo_upload=(file)
    @photo_upload = file
    return unless file.respond_to?(:read)

    @photo_bytes = file.read.b
    type = ProfilePhoto.content_type_of(@photo_bytes)
    return unless type && @photo_bytes.bytesize <= ProfilePhoto::MAX_SIZE

    (photo || build_photo).assign_attributes(data: @photo_bytes, content_type: type, byte_size: @photo_bytes.bytesize)
  end

  def remove_photo=(value)
    @remove_photo = value
    photo&.mark_for_destruction if ActiveModel::Type::Boolean.new.cast(value) && !@photo_bytes
  end

  def photo? = photo.present? && !photo.marked_for_destruction? && photo.persisted?

  private
    def photo_upload_is_an_image
      return unless @photo_bytes

      if @photo_bytes.bytesize > ProfilePhoto::MAX_SIZE
        errors.add(:photo_upload, :too_big, size: ActiveSupport::NumberHelper.number_to_human_size(ProfilePhoto::MAX_SIZE))
      elsif ProfilePhoto.content_type_of(@photo_bytes).nil?
        errors.add(:photo_upload, :not_an_image)
      end
    end
end
