module Administration
  class HomeController < ApplicationController
    def index
      authorize [ :administration, :home ]
    end
  end
end
