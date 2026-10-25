# The bank of an account is picked from Honduras' main banks or typed by
# hand ("other"); its card on the Cuentas screen has the bank's colors.
# Accounts saved before keep their bank's name, and a known one is
# recognized by it.
class AddBankKeyToMoneyAccounts < ActiveRecord::Migration[8.1]
  KNOWN = { "ficohsa" => "%ficohsa%", "atlantida" => "%atl_ntida%", "bac" => "%bac%", "occidente" => "%occidente%" }.freeze

  def up
    add_column :money_accounts, :bank_key, :string
    KNOWN.each do |key, pattern|
      execute <<~SQL.squish
        UPDATE money_accounts SET bank_key = #{quote(key)} WHERE kind = 'bank' AND bank_key IS NULL AND bank_name ILIKE #{quote(pattern)}
      SQL
    end
    execute "UPDATE money_accounts SET bank_key = 'other' WHERE kind = 'bank' AND bank_key IS NULL"
  end

  def down
    remove_column :money_accounts, :bank_key
  end

  private
    def quote(value) = connection.quote(value)
end
