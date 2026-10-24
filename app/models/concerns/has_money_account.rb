# The account a payment or collection of any module went out of or into
# (Control financiero, Fernando, 2026-10-23: «cuenta en todos los pagos»).
# Optional: older ones have none, and the balances show them apart.
module HasMoneyAccount
  extend ActiveSupport::Concern

  included do
    belongs_to :money_account, optional: true
    validate :money_account_active, if: :will_save_change_to_money_account_id?
  end

  private
    def money_account_active
      errors.add(:money_account, :inactive) if money_account && !money_account.active?
    end
end
