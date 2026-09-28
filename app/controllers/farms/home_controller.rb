module Farms
  class HomeController < ApplicationController
    def index
      authorize [ :farms, :home ]
    end
  end
end
