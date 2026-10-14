# Profile photos of people and users (Fernando, 2026-10-13), stored in the
# database like the site logo (there is no file storage on the server), in
# their own table so lists of people never load the bytes.
class CreateProfilePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :profile_photos do |t|
      t.references :owner, polymorphic: true, null: false, index: { unique: true }
      t.binary :data, null: false
      t.string :content_type, null: false
      t.integer :byte_size, null: false
      t.timestamps
    end
  end
end
