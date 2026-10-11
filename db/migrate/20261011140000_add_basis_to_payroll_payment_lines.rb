# How a payment line was earned: by day ("daily"), by cans ("harvest") or by
# tasks ("task"). A harvest payroll pays its foremen by day, so the line's
# basis no longer follows the payroll's kind.
class AddBasisToPayrollPaymentLines < ActiveRecord::Migration[8.1]
  def up
    add_column :payroll_payment_lines, :basis, :string
    execute <<~SQL
      UPDATE payroll_payment_lines SET basis = payrolls.kind
      FROM payroll_payments, payrolls
      WHERE payroll_payments.id = payroll_payment_lines.payroll_payment_id AND payrolls.id = payroll_payments.payroll_id
    SQL
    change_column_null :payroll_payment_lines, :basis, false
  end

  def down
    remove_column :payroll_payment_lines, :basis
  end
end
