class AddNameToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :name, :string
    # Existing users get the part of their email before "@" as a placeholder,
    # so the column can be required; an admin should replace it.
    execute "UPDATE users SET name = split_part(email_address, '@', 1) WHERE name IS NULL"
    change_column_null :users, :name, false
  end

  def down
    remove_column :users, :name
  end
end
