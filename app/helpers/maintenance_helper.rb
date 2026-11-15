module MaintenanceHelper
  STATUS_BADGES = { "ok" => "badge-success", "warn" => "badge-warning", "bad" => "badge-danger", "failed" => "badge-danger" }.freeze
  TIER_BADGES = { check: "badge-success", fill: "badge-warning", decision: "badge-danger" }.freeze

  def maintenance_status_badge(status)
    tag.span(t("maintenance.statuses.#{status}"), class: "badge #{STATUS_BADGES.fetch(status, "badge-neutral")}")
  end

  def maintenance_tier_badge(task)
    tag.span(t("maintenance.tiers.#{task.tier}"), class: "badge #{TIER_BADGES.fetch(task.tier)}")
  end

  # What a task runs with, in words: «Desde Lun 21/09/2026 · Días: 2».
  def maintenance_params_text(task, params)
    parts = task.params_spec.filter_map do |spec|
      value = params[spec[:name].to_s]
      next if value.blank?

      shown = case spec[:type]
      when :date then l(value.is_a?(String) ? Date.iso8601(value) : value)
      when :ids then FinanceCategory.where(id: value).map(&:full_name).sort.to_sentence
      else value
      end
      "#{t("administration.maintenance_tasks.params.#{spec[:name]}")}: #{shown}"
    end
    parts.presence&.join(" · ") || t("administration.maintenance_tasks.params.none")
  end

  # The command that does the same from the Render shell.
  def maintenance_command(task, params = {}, apply: false)
    options = task.params_spec.filter_map do |spec|
      value = params[spec[:name].to_s]
      next if value.blank?

      "#{spec[:name].to_s.upcase}=#{Array(value).join(",")}"
    end
    [ ("CONFIRM=1" if apply), "bin/rails #{task.key}", *options ].compact.join(" ")
  end
end
