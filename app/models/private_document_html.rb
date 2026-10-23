# The HTML of a private document (PrivateDocument): what the editor may
# keep, and the document filled in for a person.
#
# Only formatting survives a save (paragraphs, bold, alignment, sizes,
# lists, tables…), never scripts, events or links; and each variable keeps
# only its key, with its label inside (PrivateDocumentVariables).
module PrivateDocumentHtml
  TAGS = %w[p br div span strong b em i u s sub sup h1 h2 h3 h4 ul ol li blockquote hr
            table thead tbody tfoot tr td th colgroup col].freeze
  ATTRIBUTES = %w[style data-variable colspan rowspan width].freeze
  VARIABLES = "span[data-variable]".freeze

  module_function

  def sanitize(html)
    clean = Rails::HTML5::SafeListSanitizer.new.sanitize(html.to_s, tags: TAGS, attributes: ATTRIBUTES)
    fragment = Nokogiri::HTML5.fragment(clean)
    fragment.css(VARIABLES).each do |node|
      key = node["data-variable"]
      if PrivateDocumentVariables.known?(key)
        node.attributes.each_key { |name| node.remove_attribute(name) unless name == "data-variable" }
        node.content = "[#{PrivateDocumentVariables.label(key)}]"
      else
        node.replace(node.children)
      end
    end
    fragment.to_html.strip
  end

  # The keys of the variables the document uses, in order, once each.
  def variable_keys(html)
    Nokogiri::HTML5.fragment(html.to_s).css(VARIABLES).map { |node| node["data-variable"] }.uniq
  end

  # Nothing to read: no text, only empty paragraphs.
  def blank?(html)
    fragment = Nokogiri::HTML5.fragment(html.to_s)
    fragment.text.gsub(/[[:space:]]/, "").empty? && fragment.css(VARIABLES).empty?
  end

  # The document with each variable replaced by its value (as text, so
  # nothing in a value is read as HTML), or a blank line.
  def fill(html, variables)
    fragment = Nokogiri::HTML5.fragment(html.to_s)
    fragment.css(VARIABLES).each do |node|
      node.replace(Nokogiri::XML::Text.new(variables.value(node["data-variable"]) || PrivateDocumentVariables::BLANK, fragment.document))
    end
    fragment.to_html
  end
end
