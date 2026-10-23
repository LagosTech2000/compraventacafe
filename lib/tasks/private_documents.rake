# The text of the private documents (PrivateDocument) is the client's and
# never goes in the repository. This puts a local HTML file (written or
# exported from the editor's source view) into one of them:
#
#   bin/rails "private_documents:load[promissory_note,docs/…/pagare.html]"
#   bin/rails "private_documents:load[loan_contract,docs/…/contrato_prestamo.html]"
#
# The HTML goes through the same cleaning as the editor's, and the change
# is audited like any other.
namespace :private_documents do
  desc "Loads a local HTML file into a private document (promissory_note or loan_contract)"
  task :load, %i[key path] => :environment do |_task, args|
    abort "Usage: bin/rails \"private_documents:load[#{PrivateDocument::KEYS.join("|")},path/to/file.html]\"" unless args[:key] && args[:path]

    document = PrivateDocument.fetch(args[:key])
    document.update!(body: File.read(args[:path]))
    puts "#{document.name}: #{document.variable_keys.size} variables, #{document.body.length} characters."
  end
end
