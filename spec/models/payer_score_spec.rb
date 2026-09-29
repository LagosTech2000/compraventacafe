require "rails_helper"

RSpec.describe PayerScore do
  let(:today) { Date.new(2026, 6, 1) }

  def loan(due_on:, paid_off_on: nil)
    build(:loan, disbursed_on: due_on - 30, due_on:, paid_off_on:)
  end

  it "is the share of counted loans paid in full by their due date" do
    loans = [
      loan(due_on: today - 10, paid_off_on: today - 12), # on time
      loan(due_on: today - 10, paid_off_on: today - 5),  # late
      loan(due_on: today - 1),                           # overdue: not on time
      loan(due_on: today + 30)                           # not due yet: not counted
    ]
    score = described_class.new(loans, today:)

    expect([ score.value, score.on_time_count, score.evaluated_count ]).to eq([ 33, 1, 3 ])
    expect(score.category).to eq(:risk)
  end

  it "puts scores in categories" do
    { 100 => :excellent, 85 => :excellent, 84 => :good, 70 => :good, 69 => :fair, 50 => :fair, 49 => :risk }.each do |value, category|
      score = described_class.new([], today:)
      score.instance_variable_set(:@value, value)
      expect(score.category).to eq(category), "#{value} should be #{category}"
    end
  end

  it "has no score without paid or overdue loans" do
    score = described_class.new([ loan(due_on: today + 5) ], today:)

    expect(score.value).to be_nil
    expect(score.category).to eq(:no_history)
  end
end
