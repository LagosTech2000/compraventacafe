# Documentos privados (Fernando, 2026-10-22): the promissory note (pagaré)
# and the private loan contract, two fixed documents that admins edit and
# that are printed for a person from their credit account, filled with the
# person's (and optionally a loan's) data. There is no adding or removing
# documents: PrivateDocument.ensure_all! creates the two rows, empty (a
# fresh database loads schema.rb and skips migrations). Their text is the
# client's and never goes in the repository (it is public).
#
# Each print is recorded: who printed which document for whom (and with
# which loan), with the exact text printed.
#
# A person's civil status and nationality, optional: the contract asks
# for both.
class CreatePrivateDocuments < ActiveRecord::Migration[8.1]
  def change
    change_table :people, bulk: true do |t|
      t.string :civil_status
      t.string :nationality
    end

    create_table :private_documents do |t|
      t.string :key, null: false, index: { unique: true }
      t.text :body, null: false, default: ""
      t.references :updated_by, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    create_table :private_document_prints do |t|
      t.references :private_document, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true, index: false
      t.references :loan, foreign_key: { on_delete: :nullify }
      t.references :user, null: false, foreign_key: true
      # The document as it printed, with the values filled in.
      t.text :body, null: false
      t.timestamps
    end
    add_index :private_document_prints, %i[person_id private_document_id created_at],
              name: "index_private_document_prints_on_person_document_and_time"
  end
end
