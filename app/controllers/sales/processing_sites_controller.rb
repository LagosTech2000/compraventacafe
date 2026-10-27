module Sales
  # Where coffee is processed, and the processes done there.
  class ProcessingSitesController < ApplicationController
    before_action :set_site, only: %i[ show edit update ]

    def index
      authorize ProcessingSite
      @filter = ProcessingSiteFilter.new(params)
      @sites, @next_page = @filter.results(policy_scope(ProcessingSite))
    end

    def show
      @filter = CoffeeConversionFilter.new(params)
      @conversions, @next_page = @filter.results(policy_scope(CoffeeConversion).where(processing_site: @site))
    end

    def new
      @site = authorize ProcessingSite.new
    end

    def create
      @site = authorize ProcessingSite.new(site_params)

      if @site.save
        close_modal_with notice: t(".success"), fallback: sales_processing_site_path(@site),
                         event: "processing-site:created", detail: { id: @site.id, label: @site.name, name: @site.name }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @site.update(site_params)
        close_modal_with notice: t(".success"), fallback: sales_processing_site_path(@site)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_site
        @site = authorize ProcessingSite.find(params[:id])
      end

      def site_params
        params.expect(processing_site: [ :name, :own, :observations, :active ])
      end
  end
end
