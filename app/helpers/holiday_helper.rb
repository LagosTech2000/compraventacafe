# Small Christmas decorations while the season lasts (HolidaySeason).
module HolidayHelper
  def christmas? = @christmas.nil? ? (@christmas = HolidaySeason.christmas?) : @christmas

  # A little tree and «¡Felices fiestas!», for the greeting of the Inicio
  # and the sign-in page. Decorative: hidden from screen readers but the words.
  def holiday_greeting(css = nil)
    return unless christmas?

    tag.p(class: [ "holiday-greeting", css ].compact.join(" "), data: { holiday: true }) do
      safe_join([ holiday_tree, tag.span(t("holiday.greeting")) ])
    end
  end

  def holiday_tree
    tag.svg(class: "holiday-tree", viewBox: "0 0 24 24", width: 18, height: 18, aria: { hidden: true }) do
      safe_join([
        tag.path(d: "M12 2.5l1.1 2.2 2.4.3-1.8 1.6.5 2.4L12 7.8l-2.2 1.2.5-2.4L8.5 5l2.4-.3z", class: "holiday-star"),
        tag.path(d: "M12 7.5l4.5 6h-2.2l3.7 5H6l3.7-5H7.5z", class: "holiday-leaves"),
        tag.rect(x: 10.8, y: 18.5, width: 2.4, height: 3, rx: 0.5, class: "holiday-trunk"),
        tag.circle(cx: 10.2, cy: 12.6, r: 0.9, class: "holiday-ball holiday-ball-red"),
        tag.circle(cx: 13.9, cy: 15.8, r: 0.9, class: "holiday-ball holiday-ball-gold"),
        tag.circle(cx: 9.4, cy: 16.9, r: 0.8, class: "holiday-ball holiday-ball-red")
      ])
    end
  end
end
