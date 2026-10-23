module Loans
  # Printing the promissory note or the loan contract of a loan (Fernando,
  # 2026-10-22 and 23): the loan's buttons open the document filled in, to
  # check it first; what the person lacks can be completed there (their
  # form opens on top and the page fills in again). «Imprimir» records the
  # print (PrivateDocumentPrint), counted on the loan, and sends it to the
  # printer.
  class DocumentPrintsController < ApplicationController
    before_action :set_person

    def new
      @print = authorize PrivateDocumentPrint.new(private_document: PrivateDocument.fetch(params[:document]),
                                                  person: @person, loan: @person.loans.find(params[:loan_id]))
    end

    def create
      @print = authorize PrivateDocumentPrint.new(person: @person, user: Current.user, **print_params)
      if @print.save
        # print=1: the page opens the print dialog once.
        redirect_to loans_credit_account_document_print_path(@person, @print, print: 1), status: :see_other
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      @print = authorize @person.private_document_prints.includes(:private_document, :user, :loan).find(params[:id])
    end

    private
      def set_person
        @person = Person.find(params[:credit_account_id])
      end

      def print_params
        values = params.expect(private_document_print: [ :document_key, :loan_id ])
        { private_document: PrivateDocument.fetch(values[:document_key]), loan: @person.loans.find(values[:loan_id]) }
      end
  end
end
