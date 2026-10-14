require "zlib"

# PNG pictures made on the fly for photo specs, so big ones never live in the
# repository. With noise they barely compress: a 1500 × 1500 one weighs
# about 6.7 MB, like a phone's photo.
module ImageHelpers
  def png_picture(width, height, noise: false)
    rows = Array.new(height) do |y|
      pixels = noise ? Random.bytes(width * 3) : ([ (y * 255 / height), 120, 60 ].pack("C3") * width)
      "\x00".b + pixels
    end
    chunk = ->(type, data) { [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N") }
    png = "\x89PNG\r\n\x1A\n".b + chunk.("IHDR", [ width, height, 8, 2, 0, 0, 0 ].pack("NNCCCCC")) +
          chunk.("IDAT", Zlib::Deflate.deflate(rows.join)) + chunk.("IEND", "")

    path = Rails.root.join("tmp", "spec_pictures", "#{width}x#{height}#{"-noise" if noise}.png")
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, png)
    path.to_s
  end

  def uploaded_picture(width = 40, height = 40, **options)
    Rack::Test::UploadedFile.new(png_picture(width, height, **options), "image/png")
  end
end

RSpec.configure { |config| config.include ImageHelpers }
