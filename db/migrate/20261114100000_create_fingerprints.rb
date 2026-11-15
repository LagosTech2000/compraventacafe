# Fingerprints of people read with a ZKTeco ZK9500 (Fernando, 2026-11-14):
# each PC with a reader is a station that pairs with the app; each finger
# of a person keeps the reader's template, encrypted, never the image.
class CreateFingerprints < ActiveRecord::Migration[8.1]
  def change
    create_table :fingerprint_stations do |t|
      t.string :name, null: false
      t.string :token_digest
      t.string :pairing_code_digest
      t.datetime :pairing_expires_at
      t.datetime :paired_at
      t.datetime :last_seen_at
      t.boolean :active, null: false, default: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :fingerprint_stations, :token_digest, unique: true
    add_index :fingerprint_stations, :pairing_code_digest, unique: true

    create_table :fingerprints do |t|
      t.references :person, null: false, foreign_key: true
      t.string :finger, null: false
      t.text :template_ciphertext, null: false
      t.datetime :consented_at, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :fingerprints, %i[person_id finger], unique: true
  end
end
