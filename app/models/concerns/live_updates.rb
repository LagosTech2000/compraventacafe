# Pages that show a model's data update themselves while open when that data
# changes (Fernando, 2026-10-12). After each commit the model tells its
# streams to refresh; every page subscribed (live_updates_from in the view)
# asks the server for itself again and morphs what changed (Turbo 8 page
# refresh), each user with their own permissions. The streams carry no data,
# only "refresh". Bursts are debounced into one refresh.
#
#   class Purchase < ApplicationRecord
#     include LiveUpdates
#     live_updates :trading
#   end
module LiveUpdates
  extend ActiveSupport::Concern

  STREAMS = %i[trading loans].freeze

  class_methods do
    def live_updates(*streams)
      unknown = streams - STREAMS
      raise ArgumentError, "unknown live stream: #{unknown.join(", ")}" if unknown.any?

      after_commit { streams.each { |stream| Turbo::StreamsChannel.broadcast_refresh_later_to(stream) } }
    end
  end
end
