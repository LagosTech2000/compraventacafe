module Loans
  class HomeController < ApplicationController
    def index
      authorize [ :loans, :home ]
    end
  end
end
