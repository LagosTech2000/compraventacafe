require "rails_helper"

# A "%>" written inside an ERB comment ends the comment early, and the rest
# of it shows on the page as text (it happened in shared/_tabs).
RSpec.describe "ERB templates" do
  it "leave no stray %> once their tags are removed" do
    stray = Rails.root.glob("app/views/**/*.erb").flat_map do |path|
      source = path.read.gsub(/<%.*?%>/m) { |tag| "\n" * tag.count("\n") }
      source.each_line.with_index(1).filter_map { |line, number| "#{path.relative_path_from(Rails.root)}:#{number}" if line.include?("%>") }
    end
    expect(stray).to be_empty
  end
end
