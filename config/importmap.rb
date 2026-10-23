# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Chart.js 4.4.7, official UMD build (one file, no dependencies): importing it
# sets window.Chart. Downloaded from cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/.
pin "chart.js", to: "chart.umd.min.js"
pin "presence"
pin "instant_click"
# Leaflet 1.9.4 (BSD-2-Clause), the official minified build: importing it
# sets window.L. Downloaded from cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/
# (its stylesheet is app/assets/stylesheets/leaflet.css).
pin "leaflet", to: "leaflet.js"
# Jodit 4.17.1 (MIT), the rich text editor of private documents: the
# official "fat" build (every plugin and language, Spanish included).
# Importing it sets window.Jodit. Downloaded from
# cdn.jsdelivr.net/npm/jodit@4.17.1/es2021/ (jodit.fat.min.js; its
# stylesheet is vendor/stylesheets/jodit.css). Not preloaded: only the
# editor's page imports it, when it opens.
pin "jodit", to: "jodit.js", preload: false
