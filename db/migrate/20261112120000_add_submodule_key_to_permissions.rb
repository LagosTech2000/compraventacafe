# Permissions per submodule (Fernando, 2026-11-12): one row per user,
# module and submodule (one per tab of the module's bar). Each submodule
# starts with what the user had on its module, so nobody gains or loses
# access: the module's row becomes its first submodule (it keeps its id and
# its audit trail) and the rest are copies. SQL only, no app models: the
# list is the one of AppModule::SUBMODULES on this date.
class AddSubmoduleKeyToPermissions < ActiveRecord::Migration[8.1]
  SUBMODULES = {
    "trading" => %w[purchases invoices daily_close producers haulers zones],
    "sales" => %w[shipments sales stock coffee_conversions daily_close buyers carriers vehicles],
    "farms" => %w[payrolls farms expense_categories],
    "loans" => %w[loans credit_accounts coffee_collection collection_calendar portfolio seasons daily_close simulation supplies],
    "finance" => %w[movements incomes expenses investments accounts consolidation budget staff categories],
    "reports" => %w[reports],
    "administration" => %w[people farms zones]
  }.freeze

  def up
    add_column :permissions, :submodule_key, :string
    remove_index :permissions, %i[user_id module_key]
    execute "DELETE FROM permissions WHERE module_key NOT IN (#{SUBMODULES.keys.map { quote(it) }.join(", ")})"

    SUBMODULES.each do |module_key, submodules|
      execute <<~SQL
        UPDATE permissions SET submodule_key = #{quote(submodules.first)} WHERE module_key = #{quote(module_key)}
      SQL
      submodules.drop(1).each do |submodule_key|
        execute <<~SQL
          INSERT INTO permissions (user_id, module_key, submodule_key, can_read, can_create, can_update, can_destroy, created_at, updated_at)
          SELECT user_id, module_key, #{quote(submodule_key)}, can_read, can_create, can_update, can_destroy, NOW(), NOW()
          FROM permissions WHERE module_key = #{quote(module_key)} AND submodule_key = #{quote(submodules.first)}
        SQL
      end
    end

    change_column_null :permissions, :submodule_key, false
    add_index :permissions, %i[user_id module_key submodule_key], unique: true
  end

  def down
    # Back to one row per module: a module grants an action if any of its
    # submodules did (nobody loses access).
    execute <<~SQL
      UPDATE permissions p SET can_read = agg.can_read, can_create = agg.can_create,
                               can_update = agg.can_update, can_destroy = agg.can_destroy
      FROM (SELECT user_id, module_key, MIN(id) AS keep_id, BOOL_OR(can_read) AS can_read, BOOL_OR(can_create) AS can_create,
                   BOOL_OR(can_update) AS can_update, BOOL_OR(can_destroy) AS can_destroy
            FROM permissions GROUP BY user_id, module_key) agg
      WHERE p.id = agg.keep_id
    SQL
    execute <<~SQL
      DELETE FROM permissions p WHERE p.id NOT IN (SELECT MIN(id) FROM permissions GROUP BY user_id, module_key)
    SQL
    remove_index :permissions, %i[user_id module_key submodule_key]
    remove_column :permissions, :submodule_key
    add_index :permissions, %i[user_id module_key], unique: true
  end

  private
    def quote(value) = connection.quote(value)
end
