# Subcategories for the farms' expense categories (Fernando, 2026-11-03), in
# two levels like Control financiero's: Transporte › Combustible. A name is
# unique among its siblings, not in the whole catalog.
class AddParentToExpenseCategories < ActiveRecord::Migration[8.1]
  def change
    add_reference :expense_categories, :parent, foreign_key: { to_table: :expense_categories }, index: true
    remove_index :expense_categories, "lower((name)::text)", unique: true, name: "index_expense_categories_on_lower_name"
    add_index :expense_categories, "COALESCE(parent_id, (0)::bigint), lower((name)::text)", unique: true,
                                   name: "index_expense_categories_on_name_in_parent"
  end
end
