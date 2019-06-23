# frozen_string_literal: true

class DatabaseBlobStorage
  def initialize(blobs = DB[:blobs], variants = DB[:variants])
    @blobs    = blobs
    @variants = variants
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

      @variants.where(blob_slug: slug, variant: variant).delete if overwrite
      if @blobs.select(:blob_slug).first(blob_slug: slug).blank?
        # Insert blob because it is missing
        @blobs.insert(
          blob_slug:    slug,
          content_type: content_type,
        )
      end

      # In all cases, insert the variant
      @variants.insert(
        blob_slug:    slug,
        data:         Sequel.blob(file.read),
        variant:      variant,
      )
    end
  end

  def delete(blob_slug_or_slugs, variant: nil)
    if variant.nil?
      @blobs.where(blob_slug: blob_slug_or_slugs).delete
    else
      @variants.where(blob_slug: blob_slug_or_slugs, variant: variant).delete
    end
  end

  def data_of(slug, variant: "original", fallback: false)
    row = @blobs
      .join(@variants, [:blob_slug])
      .select(:data, :content_type)
      .first(blob_slug: slug, variant: variant)

    return [row.fetch(:data), row.fetch(:content_type)] if row

    if fallback
      row = @blobs
        .join(@variants, [:blob_slug])
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
