module Trading
  class HomeController < ApplicationController
    def index
      authorize [ :trading, :home ]
    end
  end
end
