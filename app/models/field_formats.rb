# Convention: every "obvious" field (names, DNI, RTN, phone, email) is
# validated with one of these formats, both in the model and in the form.
#
#   Model:  validates :dni, field_format: :dni
#   Form:   form.text_field :dni, **field_format_attributes(form, :dni)
#
# `pattern` is checked on the server after normalizing. `html_pattern` is the
# looser browser-side equivalent: it tolerates the separators (spaces, dashes)
# that normalization removes. Email relies on the browser's type="email".
# Messages live in es.yml under errors.messages.
module FieldFormats
  Format = Data.define(:pattern, :html_pattern, :minlength, :maxlength, :inputmode, :message) do
    def initialize(html_pattern: nil, minlength: nil, inputmode: nil, **attributes)
      super
    end
  end

  PASSWORD_MIN = 8

  REGISTRY = {
    person_name: Format.new(
      pattern: /\A\p{L}[\p{L}\s'.\-]*\z/,
      html_pattern: "\\p{L}[\\p{L}\\s'.\\-]*",
      maxlength: 100, message: :person_name_format
    ),
    dni: Format.new(
      pattern: /\A\d{13}\z/,
      html_pattern: "[\\s\\-]*(?:[0-9][\\s\\-]*){13}",
      maxlength: 17, inputmode: "numeric", message: :dni_format
    ),
    rtn: Format.new(
      pattern: /\A\d{14}\z/,
      html_pattern: "[\\s\\-]*(?:[0-9][\\s\\-]*){14}",
      maxlength: 18, inputmode: "numeric", message: :rtn_format
    ),
    phone: Format.new(
      pattern: /\A\d{8}\z/,
      html_pattern: "(?:\\+?504)?[\\s\\-]*(?:[0-9][\\s\\-]*){8}",
      maxlength: 16, inputmode: "tel", message: :phone_format
    ),
    email: Format.new(
      pattern: URI::MailTo::EMAIL_REGEXP,
      maxlength: 254, message: :email_format
    ),
    # has_secure_password caps passwords at 72 bytes.
    password: Format.new(
      pattern: /\A.{#{PASSWORD_MIN},}\z/m,
      minlength: PASSWORD_MIN, maxlength: 72, message: :password_format
    )
  }.freeze

  def self.fetch(name)
    REGISTRY.fetch(name.to_sym)
  end

  # Normalizers shared by models.
  STRIP = ->(value) { value.strip.presence }
  DIGITS = ->(value) { value.gsub(/[\s\-]/, "").presence }
  PHONE = ->(value) { value.gsub(/[\s\-]/, "").delete_prefix("+").sub(/\A504(?=\d{8}\z)/, "").presence }
  EMAIL = ->(value) { value.strip.downcase.presence }
end
