# frozen_string_literal: true

class BlobStorage
  def initialize(blobs = DB[:blobs])
    @blobs = blobs
  end

  def import(file, content_type:)
    generate_slug.tap do |slug|
      content_type = "image/jpeg"
      @blobs.insert(
        blob_slug:    slug,
        content_type: content_type,
        data:         file.read,
        variant:      "original",
      )
    end
  end

  def get(slug, variant: "original")
    blobs.select(:data).find(slug: slug, variant: variant).fetch(:data)
  end

  private

  def generate_slug
    SecureRandom.alphanumeric(24).downcase
  end
end
