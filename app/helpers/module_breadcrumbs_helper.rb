# The way up outside Fincas (shared/_breadcrumbs, Fernando, 2026-10-18: the
# same as in Fincas). A purchase or an invoice always shows its producer, a
# loan its person's account, a receipt what it was paid on, wherever it was
# opened from. Only on a full page: in a modal its own «Atrás» goes back.
module ModuleBreadcrumbsHelper
  def producer_crumbs(producer, *rest)
    [ [ t("trading.nav.producers"), trading_producers_path ], [ producer.full_name, trading_producer_path(producer) ], *rest ]
  end

  def purchase_label(purchase) = "#{t("trading.purchases.show.title")} #{purchase.id}"
  def invoice_label(invoice) = t("trading.invoices.show.title", number: invoice.display_number)

  def invoice_crumbs(invoice, *rest)
    producer_crumbs(invoice.producer, [ invoice_label(invoice), trading_invoice_path(invoice) ], *rest)
  end

  def hauler_crumbs(hauler, *rest)
    [ [ t("trading.nav.haulers"), trading_haulers_path ], [ hauler.full_name, trading_hauler_path(hauler) ], *rest ]
  end

  # Comercialización: a shipment or a sale always shows its buyer.
  # A coffee conversion goes up through the list of conversions.
  def conversion_crumbs(conversion, *rest)
    [ [ t("sales.nav.coffee_conversions"), sales_coffee_conversions_path ],
      [ t("sales.coffee_conversions.show.title", number: conversion.display_number), sales_coffee_conversion_path(conversion) ], *rest ]
  end

  def buyer_crumbs(buyer, *rest)
    [ [ t("sales.nav.buyers"), sales_buyers_path ], [ buyer.name, sales_buyer_path(buyer) ], *rest ]
  end

  def shipment_label(shipment) = t("sales.shipments.show.title", number: shipment.display_number)
  def sale_label(sale) = t("sales.sales.show.title", number: sale.display_number)

  def sale_crumbs(sale, *rest)
    buyer_crumbs(sale.buyer, [ sale_label(sale), sales_sale_path(sale) ], *rest)
  end

  def credit_account_crumbs(person, *rest)
    [ [ t("loans.nav.credit_accounts"), loans_credit_accounts_path ], [ person.full_name, loans_credit_account_path(person) ], *rest ]
  end

  def loan_crumbs(loan, *rest)
    credit_account_crumbs(loan.person, [ t("loans.loans.show.title", number: loan.id), loans_loan_path(loan) ], *rest)
  end

  def person_crumbs(person, *rest)
    [ [ t("administration.nav.people"), administration_people_path ], [ person.full_name, administration_person_path(person) ], *rest ]
  end
end
