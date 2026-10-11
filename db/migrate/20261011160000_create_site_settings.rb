# What identifies the business on screen and on paper, set by an admin:
# its name, its location and its logo. One row; the logo's bytes live in
# the database (no file storage on the server).
class CreateSiteSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :site_settings do |t|
      t.string :business_name, null: false
      t.string :location
      t.binary :logo_data
      t.string :logo_content_type
      t.string :logo_filename
      t.integer :logo_byte_size
      t.timestamps
    end
  end
end
