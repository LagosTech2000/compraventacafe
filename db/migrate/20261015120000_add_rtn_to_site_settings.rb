# The business's RTN (Fernando, 2026-10-15): optional, set in
# Configuración del sitio and printed on the invoices.
class AddRtnToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :site_settings, :rtn, :string
  end
end
