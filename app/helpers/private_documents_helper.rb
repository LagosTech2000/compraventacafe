module PrivateDocumentsHelper
  # A private document's HTML on a page: only what PrivateDocumentHtml
  # keeps, again (it was cleaned when saved; this is a second lock).
  def private_document_html(html)
    sanitize(html, tags: PrivateDocumentHtml::TAGS, attributes: PrivateDocumentHtml::ATTRIBUTES)
  end
end
