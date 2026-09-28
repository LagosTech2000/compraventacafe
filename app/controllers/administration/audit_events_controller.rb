module Administration
  class AuditEventsController < ApplicationController
    def index
      authorize AuditEvent
      @filter = AuditEventFilter.new(params)
      @events, @next_page = @filter.results(policy_scope(AuditEvent))
    end

    def show
      @event = authorize AuditEvent.find(params[:id])
    end
  end
end
