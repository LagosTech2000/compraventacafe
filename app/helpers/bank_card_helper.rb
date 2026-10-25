# The drawing of the account cards (finance/money_accounts/_card): the
# lines of the cash box's engraving, the name of the bank as set on its
# card. Decorative only: the text of the card carries the meaning.
module BankCardHelper
  # A banknote-style rosette (guilloché): a hypotrochoid with its fixed
  # circle `big`, rolling circle `small` and pen at `pen`, centered on 0,0.
  # Computed once per shape.
  def self.rosette(big:, small:, pen:, steps: 720)
    @rosettes ||= {}
    @rosettes[[ big, small, pen, steps ]] ||= begin
      turns = small / big.gcd(small)
      points = (0..steps).map do |step|
        angle = 2 * Math::PI * turns * step / steps
        x = (big - small) * Math.cos(angle) + pen * Math.cos((big - small) * angle / small)
        y = (big - small) * Math.sin(angle) - pen * Math.sin((big - small) * angle / small)
        format("%.1f %.1f", x, y)
      end
      "M#{points.first} L#{points.drop(1).join(" ")}Z"
    end
  end

  # Fine waves across the card, like the background of a banknote.
  def self.waves(count:, top:, gap:, width: 1000, amplitude: 9, length: 125)
    @waves ||= {}
    @waves[[ count, top, gap, width, amplitude, length ]] ||= Array.new(count) do |line|
      y = top + line * gap
      points = (0..width).step(10).map { |x| format("%d %.1f", x, y + amplitude * Math.sin((x + line * 18) * 2 * Math::PI / length)) }
      "M#{points.first} L#{points.drop(1).join(" ")}"
    end
  end

  def bank_card_rosette(**) = BankCardHelper.rosette(**)
  def bank_card_waves(**) = BankCardHelper.waves(**)

  # { main:, above:, below: } for the bank's name on its card.
  def bank_card_wordmark(account)
    parts = HondurasBank.wordmark(account.bank_key) || { "main" => account.bank_name }
    parts.symbolize_keys
  end
end
