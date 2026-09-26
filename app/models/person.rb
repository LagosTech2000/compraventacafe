# Identity and contact, stored once. Client and Collaborator are roles on top.
# dni (13 digits) and rtn (14 digits) are unique per person and optional.
class Person < ApplicationRecord
  has_one :client, dependent: :destroy, autosave: true
  has_one :collaborator, dependent: :destroy, autosave: true

  normalizes :first_names, :last_names, :phone, :address, with: ->(value) { value.strip.presence }
  # Accept "0704-2000-00968" or "0704 2000 00968" and store digits only.
  normalizes :dni, :rtn, with: ->(value) { value.gsub(/[\s-]/, "").presence }
  normalizes :email, with: ->(value) { value.strip.downcase.presence }

  validates :first_names, :last_names, presence: true
  validates :dni, format: { with: /\A\d{13}\z/, message: :dni_format }, uniqueness: true, allow_nil: true
  validates :rtn, format: { with: /\A\d{14}\z/, message: :rtn_format }, uniqueness: true, allow_nil: true

  scope :alphabetical, -> { order(:last_names, :first_names) }
  scope :search, ->(term) {
    pattern = "%#{sanitize_sql_like(term.strip)}%"
    where("first_names ILIKE :p OR last_names ILIKE :p OR dni ILIKE :p OR rtn ILIKE :p", p: pattern)
  }
  scope :clients, -> { joins(:client) }
  scope :collaborators, -> { joins(:collaborator) }

  def full_name
    "#{first_names} #{last_names}"
  end

  def client?
    client.present?
  end

  def collaborator?
    collaborator.present?
  end

  # Adds or removes each role from a form checkbox.
  def assign_roles(client:, collaborator:)
    toggle_role(:client, client)
    toggle_role(:collaborator, collaborator)
  end

  private
    def toggle_role(role, wanted)
      wanted = ActiveModel::Type::Boolean.new.cast(wanted)
      current = public_send(role)

      if wanted && current.nil?
        public_send("build_#{role}")
      elsif !wanted && current
        current.mark_for_destruction
      end
    end
end
