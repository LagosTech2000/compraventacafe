module Sales
  # Warehouses (client, 2026-10-26): where the coffee is kept, with the
  # coffee each one has and the transfers in and out of it.
  class WarehousesController < ApplicationController
    before_action :set_warehouse, only: %i[ show edit update destroy ]

    def index
      authorize Warehouse
      @filter = WarehouseFilter.new(params)
      @warehouses, @next_page = @filter.results(policy_scope(Warehouse))
    end

    def show
      @stock = CoffeeStock.new(warehouse: @warehouse)
      @filter = WarehouseTransferFilter.new(params)
      @transfers, @next_page = @filter.results(policy_scope(WarehouseTransfer).where(from_warehouse: @warehouse).or(policy_scope(WarehouseTransfer).where(to_warehouse: @warehouse)))
    end

    def new
      @warehouse = authorize Warehouse.new(name: next_name)
    end

    def create
      @warehouse = authorize Warehouse.new(warehouse_params)

      if @warehouse.save
        close_modal_with notice: t(".success", name: @warehouse.name), fallback: sales_warehouse_path(@warehouse),
                         event: "warehouse:created", detail: { id: @warehouse.id, label: @warehouse.name, name: @warehouse.name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @warehouse.update(warehouse_params)
        close_modal_with notice: t(".success"), fallback: sales_warehouse_path(@warehouse)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @warehouse.destroy!
      redirect_to sales_warehouses_path, notice: t(".success", name: @warehouse.name), status: :see_other
    end

    private
      def set_warehouse
        @warehouse = authorize Warehouse.find(params[:id])
      end

      def warehouse_params
        params.expect(warehouse: [ :name, :main, :observations, :active ])
      end

      # «Bodega N»: the first number no warehouse has.
      def next_name
        names = Warehouse.pluck(:name).map(&:downcase)
        number = (1..).find { !names.include?(t("sales.warehouses.numbered", number: it).downcase) }
        t("sales.warehouses.numbered", number:)
      end
  end
end
