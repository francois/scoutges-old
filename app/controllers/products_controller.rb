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
    required(:quantity).filled(:integer)
    required(:category_codes).array(Types::StrippedString)
    required(:image_url).maybe(Types::StrippedString)
  end

  ChangeProductSchema = Dry::Schema.Params do
    required(:name).filled(Types::StrippedString)
    required(:description).maybe(Types::StrippedString)
    required(:internal_unit_price).filled(:decimal)
    required(:external_unit_price).filled(:decimal)
    required(:building).maybe(Types::StrippedString)
    required(:room).maybe(Types::StrippedString)
    required(:aisle).maybe(Types::StrippedString)
    required(:bin).maybe(Types::StrippedString)
    required(:quantity).filled(:integer)
    required(:category_codes).array(Types::StrippedString)
    required(:image_url).maybe(Types::StrippedString)
  end

  def index
    set_group

    @category_codes = Scoutinv.new.find_category_codes
    @category_code = params[:category_code].blank? ? nil : params[:category_code]
    @q = params[:q]
    @products = Scoutinv.new.find_products(
      group_slug: @group.fetch(:group_slug),
      search_string: @q,
      category_codes: Array(@category_code).empty? ? @category_codes : Array(@category_code),
      after: params[:after],
      before: params[:before],
    )

    @products = @products.map do |product|
      product[:image_paths] = product.fetch(:blob_slugs).map do |blob_slug|
        blob_path(blob_slug, format: "jpg", variant: "small", fallback: true)
      end

      product
    end

    render
  end

  def show
    scoutinv = Scoutinv.new

    @product = scoutinv.find_product(group_slug: params[:group_id], product_slug: params[:id])
    @product[:image_paths] = @product.fetch(:blob_slugs).map do |blob_slug|
      blob_path(blob_slug, format: "jpg", variant: "medium", fallback: true)
    end

    @reservations = scoutinv.find_product_reservations(group_slug: @product[:group_slug], product_slug: @product[:product_slug], cutoff_on: 2.years.ago.to_date)
    render
  end

  def new
    set_group
    @category_codes = Scoutinv.new.find_category_codes
    @product = {num_instances: 1, category_codes: []}
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
        output[:images] << params[:product][:image] if params[:product][:image]

        # Handle upload by image URL
        output[:images] << import_image(output.fetch(:image_url)) if output.fetch(:image_url)

        scoutinv = Scoutinv.new
        product_slug = DB.transaction do
          scoutinv.register_product(
            aisle:                output.fetch(:aisle),
            bin:                  output.fetch(:bin),
            building:             output.fetch(:building),
            category_codes:       output.fetch(:category_codes),
            description:          output.fetch(:description) || "",
            external_unit_price:  output.fetch(:external_unit_price),
            group_slug:           @group.fetch(:group_slug),
            images:               output.fetch(:images),
            internal_unit_price:  output.fetch(:internal_unit_price),
            name:                 output.fetch(:name),
            room:                 output.fetch(:room),
          ).tap do |product_slug|
            scoutinv.change_product_quantity(
              group_slug: @group.fetch(:group_slug),
              product_slug: product_slug,
              quantity: output.fetch(:quantity),
            )

            product = scoutinv.find_product(group_slug: @group.fetch(:group_slug), product_slug: product_slug)
            product.fetch(:blob_slugs).each do |blob_slug|
              Rails.logger.info "Enqueuing create-image-variants job for #{blob_slug.inspect}"
              CreateImageVariantsJob.enqueue(blob_slug)
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
        .slice(:name, :description, :internal_unit_price, :external_unit_price, :building, :room, :aisle, :bin, :image_url, :category_codes)
        .merge(group_slug: @group.fetch(:group_slug))
      @category_codes = Scoutinv.new.find_category_codes
      render action: :new
    end
  end

  def edit
    set_group
    scoutinv = Scoutinv.new
    @category_codes = scoutinv.find_category_codes
    @product = scoutinv.find_product(group_slug: params[:group_id], product_slug: params[:id])
    @product[:image_paths] = @product.fetch(:blob_slugs).map do |blob_slug|
      blob_path(blob_slug, format: "jpg", variant: "medium", fallback: true)
    end
    render
  end

  def update
    set_group
    scoutinv = Scoutinv.new
    @result = ChangeProductSchema.call(params[:product].to_h)
    if @result.success?
      output = @result.output
      begin
        output[:images] = []

        # Handle direct file uploads
        output[:images] << params[:product][:image] if params[:product][:image]

        # Handle upload by image URL
        output[:images] << import_image(output.fetch(:image_url)) if output[:image_url]

        DB.transaction do
          scoutinv.change_product_details(
            aisle:                output.fetch(:aisle),
            bin:                  output.fetch(:bin),
            building:             output.fetch(:building),
            category_codes:       output.fetch(:category_codes),
            description:          output.fetch(:description) || "",
            external_unit_price:  output.fetch(:external_unit_price),
            group_slug:           @group.fetch(:group_slug),
            images:               output.fetch(:images),
            internal_unit_price:  output.fetch(:internal_unit_price),
            name:                 output.fetch(:name),
            product_slug:         params[:id],
            room:                 output.fetch(:room),
          )

          scoutinv.change_product_quantity(
            group_slug: @group.fetch(:group_slug),
            product_slug: params[:id],
            quantity: output.fetch(:quantity),
          )

          product = scoutinv.find_product(group_slug: @group.fetch(:group_slug), product_slug: params[:id])
          product.fetch(:blob_slugs).each do |blob_slug|
            Rails.logger.info "Enqueuing create-image-variants job for #{blob_slug.inspect}"
            CreateImageVariantsJob.enqueue(blob_slug)
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

      redirect_to group_product_path(@group.fetch(:group_slug), params[:id])
    else
      @product = params[:product]
        .slice(:name, :description, :internal_unit_price, :external_unit_price, :building, :room, :aisle, :bin, :image_url, :category_codes)
        .merge(group_slug: params[:group_id], product_slug: params[:id])
      @category_codes = Scoutinv.new.find_category_codes
      render action: :edit
    end
  end

  def destroy
    scoutinv = Scoutinv.new
    DB.transaction do
      product = scoutinv.find_product(group_slug: params[:group_id], product_slug: params[:id])
      scoutinv.remove_product(group_slug: product.fetch(:group_slug), product_slug: product.fetch(:product_slug))
      RemoveOrphanedBlobsJob.enqueue(product.fetch(:blob_slugs)) if product.fetch(:blob_slugs).any?
    end

    redirect_to group_products_path(params[:group_id])
  end

  private

  def set_group
    @group = Scoutinv.new.find_group(params[:group_id])
  end

  def import_image(image_url)
    image = Tempfile.open("temp", encoding: "ascii-8bit")
    image.tap do
      image.write(Net::HTTP.get(URI(image_url)))
      image.rewind
    end
  end
end
