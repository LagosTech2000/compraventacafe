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
