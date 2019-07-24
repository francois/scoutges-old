# frozen_string_literal: true
require "types"

class ReservationsController < ApplicationController
  def show
    set_group
    scoutinv = Scoutinv.new
    @entities = scoutinv.find_entities_available_for_rental(
      category_codes: scoutinv.find_category_codes,
      group_slug: @group.fetch(:group_slug),
      search_string: nil,
    )

    @entities = @entities.map do |entity|
      entity[:image_paths] = entity.fetch(:blob_slugs).map do |blob_slug|
        blob_path(blob_slug, format: "jpg", variant: "small", fallback: true)
      end

      entity
    end

    render
  end

  private

  def set_group
    @group = Scoutinv.new.find_group(params[:group_id])
  end
end
