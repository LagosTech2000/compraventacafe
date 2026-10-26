# Where a coffee conversion is: weighed (what went in, in process) → its
# result entered (finished).
class ConversionLifecycle
  include LifecycleSteps

  STAGES = %w[weighed finished].freeze

  def self.for(conversion) = new(conversion.finished? ? "finished" : "weighed")
end
