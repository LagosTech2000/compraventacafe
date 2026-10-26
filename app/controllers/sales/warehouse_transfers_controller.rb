module Sales
  # Coffee moved from one warehouse to another (client, 2026-10-26), with
  # its history; the oldest lots go first (CoffeeLots).
  class WarehouseTransfersController < ApplicationController
    before_action :set_transfer, only: %i[ show void ]

    def index
      authorize WarehouseTransfer
      @filter = WarehouseTransferFilter.new(params)
      @transfers, @next_page = @filter.results(policy_scope(WarehouseTransfer))
    end

    def show
      @portions = CoffeeLots.new.portions_for(@transfer)
    end

    def new
      from = Warehouse.active.find_by(id: params[:from_warehouse_id]) || Warehouse.main
      state = params[:coffee_state].presence_in(Purchase::COFFEE_STATES) || PurchaseDefaults::COFFEE_STATE
      @transfer = authorize WarehouseTransfer.new(transferred_at: Time.current.change(sec: 0), from_warehouse: from, coffee_state: state,
                                                  to_warehouse: Warehouse.active.where.not(id: from&.id).alphabetical.first)
    end

    def create
      @transfer = authorize WarehouseTransfer.new(transfer_params.merge(created_by: Current.user))

      if @transfer.save
        close_modal_with notice: t(".success", number: @transfer.display_number), fallback: sales_warehouse_transfer_path(@transfer)
      else
        render :new, status: :unprocessable_content
      end
    end

    def void
      authorize @transfer, :void?
      @transfer.void!(Current.user)

      if modal_request?
        close_modal_with notice: t(".success"), fallback: sales_warehouse_transfers_path
      else
        redirect_back_or_to sales_warehouse_transfers_path, notice: t(".success")
      end
    end

    private
      def set_transfer
        @transfer = WarehouseTransfer.includes(:from_warehouse, :to_warehouse, :created_by, :voided_by).find(params[:id])
        authorize @transfer unless action_name == "void"
      end

      def transfer_params
        params.expect(warehouse_transfer: [ :transferred_at, :from_warehouse_id, :to_warehouse_id, :coffee_state, :net_weight, :observations ])
      end
  end
end
