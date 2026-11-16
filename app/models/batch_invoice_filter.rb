# The invoices to choose for a lot (Sales → Lotes → «Agregar facturas»):
# the invoices' filters, and every column sorts (Fernando, 2026-11-16),
# also the part still free.
class BatchInvoiceFilter < InvoiceFilter
  FREE = "(100 - COALESCE((SELECT SUM(coffee_batch_invoices.percent) FROM coffee_batch_invoices WHERE coffee_batch_invoices.invoice_id = invoices.id), 0))".freeze

  sorts free: FREE
end
