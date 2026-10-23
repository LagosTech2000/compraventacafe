# The steps of a record's life, in order (its class's STAGES), and where it
# is: what shared/_lifecycle draws, with the button of the next step.
# TradingLifecycle (a purchase) and LoanLifecycle (a loan) use it.
module LifecycleSteps
  attr_reader :stage

  def initialize(stage)
    raise ArgumentError, "unknown stage #{stage}" unless stages.include?(stage)

    @stage = stage
  end

  def stages = self.class::STAGES

  # :done for reached steps, :next for the one to do now, :upcoming after it.
  def status(step)
    reached = stages.index(stage)
    index = stages.index(step)
    return :done if index <= reached

    index == reached + 1 ? :next : :upcoming
  end

  def next_stage = stages[stages.index(stage) + 1]
  def complete? = next_stage.nil?
  def step_number(step) = stages.index(step) + 1
end
