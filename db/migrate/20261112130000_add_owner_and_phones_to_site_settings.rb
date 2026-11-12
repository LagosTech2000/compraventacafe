# The remission of a shipment (Fernando, 2026-11-12) says who the business
# belongs to («De: …», also «Enviadas por») and its phones, as the client's
# booklet does. Both optional.
class AddOwnerAndPhonesToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :site_settings, :owner_name, :string
    add_column :site_settings, :phone, :string
    add_column :site_settings, :secondary_phone, :string
  end
end
