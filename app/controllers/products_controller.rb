# frozen_string_literal: true
require "net/http"
require "types"
require "uri"

class ProductsController < ApplicationController
  NewProductSchema = Dry::Schema.Params do
    required(:name).filled(Types::StrippedString)
    required(:description).maybe(Types::StrippedString)
    required(:internal_unit_price).filled(:decimal)
    required(:external_unit_price).filled(:decimal)
    required(:building).maybe(Types::StrippedString)
    required(:room).maybe(Types::StrippedString)
    required(:aisle).maybe(Types::StrippedString)
    required(:bin).maybe(Types::StrippedString)
    required(:image)
    required(:image_url).maybe(Types::StrippedString)
  end

  def new
    set_group
    @product = Hash.new
    render
  end

  def create
    set_group
    @result = NewProductSchema.call(params[:product].to_h)
    if @result.success?
      output = @result.output
      begin
        output[:images] = []

        # Handle direct file uploads
        output[:images] << output.fetch(:image) if output.fetch(:image)

        # Handle upload by image URL
        output[:images] << import_image(output.fetch(:image_url)) if output.fetch(:image_url)

        scoutinv = Scoutinv.new
        product_slug = DB.transaction do
          scoutinv.register_product(
            aisle:                output.fetch(:aisle),
            bin:                  output.fetch(:bin),
            building:             output.fetch(:building),
            description:          output.fetch(:description) || "",
            external_unit_price:  output.fetch(:external_unit_price),
            group_slug:           @group.fetch(:group_slug),
            images:               output.fetch(:images),
            internal_unit_price:  output.fetch(:internal_unit_price),
            name:                 output.fetch(:name),
            room:                 output.fetch(:room),
          ).tap do |product_slug|
            product = scoutinv.find_product(group_slug: @group.fetch(:group_slug), product_slug: product_slug)
            product.fetch(:blob_slugs).each do |blob_slug|
              Rails.logger.info "Enqueuing create-image-variants job for #{blob_slug.inspect}"
              CreateImageVariants.enqueue(blob_slug)
            end
          end
        end
      ensure
        # Make sure we don't keep open files around
        output[:images].select{|im| im.respond_to?(:close) }.each(&:close)

        # And make sure we don't waste disk space with unnecessary files
        output[:images].select{|im| im.respond_to?(:delete)}.each(&:delete)

        # We need this ensure block because we don't use the block
        # form of Tempfile#open, when importing images by URL.
      end

      redirect_to group_product_path(@group.fetch(:group_slug), product_slug)
    else
      @product = params[:product]
        .slice(:name, :description, :internal_unit_price, :external_unit_price, :building, :room, :aisle, :bin)
      render action: :new
    end
  end

  def show
    @product = Scoutinv.new.find_product(group_slug: params[:group_id], product_slug: params[:id])
    @product[:image_paths] = @product.fetch(:blob_slugs).map do |blob_slug|
      blob_path(blob_slug, format: "jpg", variant: "medium", fallback: true)
    end

    render
  end

  private

  def set_group
    @group = Scoutinv.new.find_group(params[:group_id])
  end

  def import_image(image_url)
    Tempfile.open("temp", encoding: "ascii-8bit").tap do |image|
      uri = URI(image_url)

      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri)

        http.request(request) do |response|
          response.read_body do |chunk|
            image.write(chunk)
          end
        end
      end

      image.rewind
    end
  end
end
