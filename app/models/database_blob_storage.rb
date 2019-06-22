# frozen_string_literal: true

class DatabaseBlobStorage
  def initialize(blobs = DB[:blobs])
    @blobs = blobs
  end

  def import(file, parent_slug: nil, content_type: nil, variant: "original", overwrite: false)
    (parent_slug || generate_slug).tap do |slug|
      if content_type.blank?
        command = Escape.shell_command(["identify", file.path])
        content_type =
          case `#{command}`
          when /\bPNG\b/  ; "image/png"
          when /\bJPEG\b/ ; "image/jpeg"
          when /\bGIF\b/  ; "image/gif"
          else            ; "application/octet-stream"
          end
      end

      @blobs.where(blob_slug: slug, variant: variant).delete if overwrite
      @blobs.insert(
        blob_slug:    slug,
        content_type: content_type,
        data:         Sequel.blob(file.read),
        variant:      variant,
      )
    end
  end

  def delete(blob_slug, variant: nil)
    ds = @blobs.where(blob_slug: blob_slug)
    ds = ds.where(variant: variant) if variant
    ds.delete
  end

  def data_of(slug, variant: "original", fallback: false)
    row = @blobs
      .select(:data, :content_type)
      .first(blob_slug: slug, variant: variant)

    return [row.fetch(:data), row.fetch(:content_type)] if row

    if fallback
      row = @blobs
        .select(:data, :content_type)
        .first(blob_slug: slug, variant: "original")
      [row.fetch(:data), row.fetch(:content_type)] if row
    end
  end

  private

  def generate_slug
    SecureRandom.alphanumeric(24).downcase
  end
end
