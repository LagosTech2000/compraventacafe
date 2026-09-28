module Reports
  class HomeController < ApplicationController
    def index
      authorize [ :reports, :home ]
    end
  end
end
