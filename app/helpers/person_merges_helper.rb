module PersonMergesHelper
  # A detail of one side of a merge (PersonMerge), as the person page shows it.
  def person_merge_value(field, record)
    return "—" unless record

    value = case field
    when "phone" then format_phone(record.phone)
    when "zone" then record.zone&.name
    when "address" then format_address(record)
    when "location" then ([ record.latitude, record.longitude ].join(", ") if record.located?)
    when "photo" then (avatar(record, css: "size-12") if record.photo?)
    when "kind" then record.human_kind
    else record.public_send(field)
    end
    value.presence || tag.span(t("administration.person_merges.new.empty"), class: "text-ink-muted")
  end
end
