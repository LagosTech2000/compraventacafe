# Rails turns YJIT (Ruby's faster engine) on by itself when the Ruby that
# runs the app has it (config.yjit, on by default since Rails 7.2). The log
# says at boot whether it did, so it can be checked on Render.
Rails.application.config.after_initialize do
  enabled = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
  Rails.logger.info(enabled ? "YJIT enabled" : "YJIT not available in this Ruby (#{RUBY_DESCRIPTION})")
end
