module Finance
  # Serves an expense's receipt (photo or PDF) to who can see the expense.
  class ExpenseReceiptsController < ApplicationController
    def show
      receipt = authorize ExpenseReceipt.find(params[:id])
      expires_in 1.year, public: false if params[:v] == receipt.version.to_s
      send_data receipt.data, type: receipt.content_type, disposition: "inline",
                              filename: receipt.filename || "comprobante#{receipt.pdf? ? ".pdf" : ""}"
    end
  end
end
