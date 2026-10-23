# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Stylesheets of vendored libraries that only some pages link (Jodit's, for
# the editor of private documents): outside app/assets/stylesheets, so the
# :app stylesheets of every page leave them out.
Rails.application.config.assets.paths << Rails.root.join("vendor/stylesheets")
