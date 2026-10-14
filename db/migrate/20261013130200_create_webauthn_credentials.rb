# Signing in with a fingerprint (Fernando, 2026-10-13): each user registers
# the passkeys of their devices (WebAuthn) from Mi configuración, as one
# more way in; the password keeps working.
class CreateWebauthnCredentials < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :webauthn_id, :string
    add_index :users, :webauthn_id, unique: true

    create_table :webauthn_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id, null: false, index: { unique: true }
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
      t.string :nickname, null: false
      t.datetime :last_used_at
      t.timestamps
    end
  end
end
