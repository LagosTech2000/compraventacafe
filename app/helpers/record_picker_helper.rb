# The data attributes of a searchable picker (record_picker_controller.js):
# where it searches (PickerSearch kind), the record already chosen and its
# messages. Merge them into the element around shared/_record_picker_search:
#
#   tag.div data: { controller: "record-picker", **record_picker_data(:producers, selected: purchase.producer, ...) }
module RecordPickerHelper
  def record_picker_data(kind, selected:, missing_message:, except: nil)
    { record_picker_url_value: picker_search_path(kind, except:),
      record_picker_selected_value: (selected ? PickerSearch.data(selected) : {}).to_json,
      record_picker_missing_message_value: missing_message,
      record_picker_min_length_value: PickerSearch::MIN_LENGTH,
      record_picker_texts_value: t("shared.record_picker").merge(short: t("shared.record_picker.short", count: PickerSearch::MIN_LENGTH)).to_json }
  end

  # The notice of a picked person's empty details (shared/_person_gaps,
  # record_gaps_controller.js): its message and where «Completar datos» goes.
  def person_gaps_data(person)
    { record_gaps_missing_value: (person ? { person.id => person.missing_fields } : {}).to_json,
      record_gaps_message_value: t("shared.person_gaps.message"),
      record_gaps_edit_url_value: edit_administration_person_path("__id__", picker: 1),
      record_gaps_record_value: person&.id }
  end
end
