# frozen_string_literal: true

class RemoveOrphanedBlobsJob < Que::Job
  def run(blob_slugs)
    return destroy if Array(blob_slugs).empty?

    storage  = DatabaseBlobStorage.new

    service = S3::Service.new(
      access_key_id:      Rails.application.credentials.dig(Rails.env.to_sym, :aws, :access_key_id),
      secret_access_key:  Rails.application.credentials.dig(Rails.env.to_sym, :aws, :secret_access_key),
    )

    bucket = service.bucket(Rails.application.credentials.dig(Rails.env.to_sym, :aws, :bucket))

    DB.transaction do
      bucket.objects
        .select{|object| (object.key.split(/\b/) & blob_slugs).any?}
        .each(&:destroy)
      storage.delete(blob_slugs)
      destroy
    end
  end
end
