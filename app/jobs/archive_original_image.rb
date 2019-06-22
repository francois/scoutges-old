# frozen_string_literal: true

class ArchiveOriginalImage < Que::Job
  def run(blob_slug)
    storage = DatabaseBlobStorage.new

    service = S3::Service.new(
      access_key_id:     Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key),
    )

    bucket = service.bucket(ENV.fetch("AWS_BUCKET"))

    DB.transaction do
      data, content_type = storage.data_of(blob_slug)

      extension =
        case content_type
        when "image/jpeg", "image/jpg" ; "jpg"
        when "image/png"               ; "png"
        when "image/gif"               ; "gif"
        else
          raise ArgumentError, "Unrecognized content-type: #{content_type.inspect}"
        end

      object = bucket.objects.build("blobs/originals/#{blob_slug}.#{extension}")
      object.acl = :private
      object.content = data
      object.content_type = content_type
      object.save

      storage.delete(blob_slug, variant: "original")
      destroy
    end
  end
end
