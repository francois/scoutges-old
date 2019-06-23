# frozen_string_literal: true

class CreateImageVariantsJob < Que::Job
  def run(blob_slug)
    blob_storage = DatabaseBlobStorage.new

    Rails.logger.info "Starting #{self.class} with #{blob_slug.inspect}"
    data, _ = blob_storage.data_of(blob_slug)
    Rails.logger.info "Blob size: #{data.length}"

    DB.transaction do
      Tempfile.open("original", encoding: "ascii-8bit") do |io|
        io.write(data)
        io.close

        Rails.logger.info "Building small variant"
        small_path = generate_small(io.path)
        File.open(small_path, encoding: "ascii-8bit") do |stream|
          blob_storage.import(stream, parent_slug: blob_slug, content_type: "image/jpeg", variant: "small", overwrite: true)
        end

        Rails.logger.info "Building medium variant"
        medium_path = generate_medium(io.path)
        File.open(medium_path, encoding: "ascii-8bit") do |stream|
          blob_storage.import(stream, parent_slug: blob_slug, content_type: "image/jpeg", variant: "medium", overwrite: true)
        end

        Rails.logger.info "Building large variant"
        large_path = generate_large(io.path)
        File.open(large_path, encoding: "ascii-8bit") do |stream|
          blob_storage.import(stream, parent_slug: blob_slug, content_type: "image/jpeg", variant: "large", overwrite: true)
        end
      end

      Rails.logger.info "Scheduling ArchiveOriginalImageJob for #{blob_slug.inspect}"
      ArchiveOriginalImageJob.enqueue(blob_slug)
      destroy
    end
  end

  def generate_small(original_path)
    convert(original_path, size: "200x200^", quality: "60", gravity: "Center", crop: "200x200+0+0", repage: true)
  end

  def generate_medium(original_path)
    convert(original_path, size: "500x", quality: "80")
  end

  def generate_large(original_path)
    convert(original_path, size: "1000x", quality: "80")
  end

  def convert(path, size:, quality: "80", crop: nil, gravity: nil, repage: false)
    Tempfile.open("temp", encoding: "ascii-8bit") do |temp|
      temp.close
      "#{temp.path}.jpg".freeze.tap do |final|

        cmd = []
        cmd << "convert"
        cmd << path
        cmd << "-strip"
        cmd << "-resize" << size
        cmd << "-quality" << quality
        cmd << "-gravity" << gravity if gravity
        cmd << "-crop" << crop if crop
        cmd << "+repage" if repage
        cmd << final

        system(Escape.shell_command(cmd))
      end
    end
  end
end
