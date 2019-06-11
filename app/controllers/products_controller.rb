# frozen_string_literal: true
require "types"

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
      scoutinv = Scoutinv.new
      product_slug = DB.transaction do
        scoutinv.register_product(
          aisle:                output.fetch(:aisle),
          bin:                  output.fetch(:bin),
          building:             output.fetch(:building),
          description:          output.fetch(:description) || "",
          external_unit_price:  output.fetch(:external_unit_price),
          group_slug:           @group.fetch(:group_slug),
          images:               [],
          internal_unit_price:  output.fetch(:internal_unit_price),
          name:                 output.fetch(:name),
          room:                 output.fetch(:room),
        )
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
    render
  end

  private

  def set_group
    @group = Scoutinv.new.find_group(params[:group_id])
  end
end
