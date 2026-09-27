# Creates the first administrator from the environment. Credentials never
# live in the repository.
#
#   ADMIN_NAME="..." ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/rails db:seed
#
# Idempotent: if the user already exists, nothing changes.

name = ENV["ADMIN_NAME"].to_s.strip
email = ENV["ADMIN_EMAIL"].to_s.strip
password = ENV["ADMIN_PASSWORD"].to_s

if name.empty? || email.empty? || password.empty?
  abort "db:seed requires ADMIN_NAME, ADMIN_EMAIL and ADMIN_PASSWORD in the environment."
end

if User.exists?(email_address: email.downcase)
  puts "Admin #{email} already exists; nothing changed."
else
  User.create!(name:, email_address: email, password:, admin: true, active: true)
  puts "Admin #{email} created."
end
