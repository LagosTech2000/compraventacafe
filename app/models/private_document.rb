# Documentos privados (Fernando, 2026-10-22): the promissory note (pagaré)
# and the private loan contract. Two fixed documents: admins edit their
# text in Administración (with a rich text editor and variables), nobody
# adds or removes one. They print for a person from their credit account
# (PrivateDocumentPrint), filled with the person's data and, if chosen, one
# of their loans (PrivateDocumentVariables).
#
# Their text is the client's: it lives in the database only, never in the
# repository (it is public). `bin/rails private_documents:load` puts a
# local HTML file into one of them.
class PrivateDocument < ApplicationRecord
  include Auditable

  KEYS = %w[promissory_note loan_contract].freeze
  MAX_BODY = 500_000

  belongs_to :updated_by, class_name: "User", optional: true
  has_many :prints, class_name: "PrivateDocumentPrint", dependent: :restrict_with_error

  normalizes :body, with: ->(html) { PrivateDocumentHtml.sanitize(html) }

  validates :key, inclusion: { in: KEYS }, uniqueness: true
  validates :body, length: { maximum: MAX_BODY }

  # The two rows, created when missing (a fresh database loads schema.rb
  # and skips the migrations). Idempotent.
  def self.ensure_all!
    return if where(key: KEYS).count == KEYS.size

    insert_all(KEYS.map { |key| { key:, body: "" } }, unique_by: :key)
  end

  # Both, in their fixed order.
  def self.ordered
    ensure_all!
    where(key: KEYS).includes(:updated_by).sort_by { |document| KEYS.index(document.key) }
  end

  def self.fetch(key)
    ensure_all!
    find_by!(key: key.to_s)
  end

  def to_param = key

  def name = I18n.t("private_documents.names.#{key}")

  def description = I18n.t("private_documents.descriptions.#{key}")

  alias_method :audit_label, :name

  def blank_body? = PrivateDocumentHtml.blank?(body)

  def variable_keys = PrivateDocumentHtml.variable_keys(body)

  # Filled in for a person (and a loan of theirs, or none).
  def filled_body(person:, loan: nil)
    PrivateDocumentHtml.fill(body, PrivateDocumentVariables.new(person:, loan:))
  end
end
