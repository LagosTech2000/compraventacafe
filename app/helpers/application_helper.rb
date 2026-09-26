module ApplicationHelper
  def readable_module_keys
    return [] unless Current.user

    AppModule::KEYS.select { |key| Current.user.can?(key, :read) }
  end

  def module_root_path(key)
    public_send("#{key}_root_path")
  end

  def nav_link_class(path)
    base = "block rounded-2xl px-4 py-2 text-sm font-medium transition"
    if current_page?(path) || request.path.start_with?("#{path}/")
      "#{base} bg-primary text-on-primary"
    else
      "#{base} text-ink hover:bg-primary-soft"
    end
  end
end
