module Administration
  # Documentos privados (Fernando, 2026-10-22): the promissory note and the
  # loan contract, always these two. Admins read and edit their text with
  # a rich text editor and variables; they print from a person's credit
  # account (Loans::DocumentPrintsController).
  class PrivateDocumentsController < ApplicationController
    before_action :set_document, only: %i[ show edit update ]

    def index
      authorize PrivateDocument
      @documents = PrivateDocument.ordered
    end

    def show
    end

    def edit
    end

    def update
      if @document.update(document_params.merge(updated_by: Current.user))
        redirect_to administration_private_document_path(@document), notice: t(".success", name: @document.name)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_document
        @document = authorize PrivateDocument.fetch(params[:id])
      end

      def document_params
        params.expect(private_document: [ :body, :lock_version ])
      end
  end
end
