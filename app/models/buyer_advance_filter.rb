# Every advance of buyers and banks (Comercialización → Compradores →
# Anticipos, Fernando, 2026-11-16): by status, buyer, dates and text.
class BuyerAdvanceFilter < ListFilter
  field :from, :date
  field :to, :date
  field :q, :text
  field :buyer_id, :id
  field :status, :choice, in: BuyerAdvance::STATUSES

  sorts number: "buyer_advances.id", received_on: "buyer_advances.received_on",
        buyer: { sql: text("buyers.name"), joins: :buyer },
        amount: "buyer_advances.amount", applied: BuyerAdvance::APPLIED_SQL, refunded: BuyerAdvance::REFUNDED_SQL,
        balance: BuyerAdvance::BALANCE_SQL, status: "buyer_advances.status"

  def apply(scope)
    scope = scope.where(received_on: from..) if from
    scope = scope.where(received_on: ..to) if to
    scope = scope.where(buyer_id:) if buyer_id
    scope = scope.where(status:) if status
    if q
      buyers = Buyer.where("buyers.name ILIKE ?", like(q)).select(:id)
      scope = scope.where(buyer_id: buyers).or(scope.where("buyer_advances.document_number ILIKE ?", like(q)))
    end
    scope.includes(:buyer, :money_account, :applications, :refunds).newest_first
  end
end
