FactoryBot.define do
  # One of the two fixed documents, with a text that has a variable.
  factory :private_document_print do
    private_document do
      PrivateDocument.fetch("promissory_note").tap do |document|
        document.update!(body: %(<p>Pagaré de <span data-variable="person.full_name">x</span></p>)) if document.blank_body?
      end
    end
    person
    loan { association :loan, person: }
    user
  end
end
