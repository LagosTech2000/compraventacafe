module Sales
  # «Nueva salida» (client, 2026-10-26): the coffee does not always leave to
  # be sold. First the kind: a sale (a truck to a buyer), processing (cherry
  # to wet parchment, wet to dry) or a transfer between warehouses; each one
  # opens its own form.
  class DeparturesController < ApplicationController
    def new
      authorize [ :sales, :departure ], :create?
    end
  end
end
