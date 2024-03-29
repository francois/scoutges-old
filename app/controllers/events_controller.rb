# frozen_string_literal: true
require "types"

class EventsController < ApplicationController
  EventSchema = Dry::Schema.Params do
    required(:name).filled(Types::StrippedString)
    required(:description).maybe(Types::StrippedString)
    required(:lease_on).filled(:date)
    required(:start_on).filled(:date)
    required(:end_on).filled(:date)
    required(:return_on).filled(:date)

    # One of troop_slug OR leaser_name/leaser_phone/leaser_email must be filled in
    required(:troop_slug).maybe(Types::StrippedString)

    required(:leaser_name).maybe(Types::StrippedString)
    required(:leaser_phone).maybe(Types::StrippedString)
    required(:leaser_email).maybe(Types::StrippedString, format?: /\A[^@]+@.+[.][a-z]{2,}\z/i)
  end

  def index
    set_group
    @after  = (params[:after] || 14.days.ago).to_date
    @q = params[:q]
    @events = Scoutinv.new.find_events(group_slug: @group.fetch(:group_slug), after: @after, search_string: @q)
    render
  end

  def new
    set_group
    @event = Hash.new
    render
  end

  def create
    set_group
    @result = EventSchema.call(params[:event].to_h)
    if @result.success?
      output     = @result.output
      scoutinv   = Scoutinv.new
      event_slug = DB.transaction do
        if output[:troop_slug]
          scoutinv.register_troop_event(
            description:  output.fetch(:description) || "",
            end_on:       output.fetch(:end_on),
            group_slug:   @group.fetch(:group_slug),
            lease_on:     output.fetch(:lease_on),
            name:         output.fetch(:name),
            return_on:    output.fetch(:return_on),
            start_on:     output.fetch(:start_on),
            troop_slug:   output.fetch(:troop_slug),
          )
        else
          scoutinv.register_external_event(
            description:  output.fetch(:description) || "",
            end_on:       output.fetch(:end_on),
            group_slug:   @group.fetch(:group_slug),
            lease_on:     output.fetch(:lease_on),
            leaser_email: output.fetch(:leaser_email),
            leaser_name:  output.fetch(:leaser_name),
            leaser_phone: output.fetch(:leaser_phone),
            name:         output.fetch(:name),
            return_on:    output.fetch(:return_on),
            start_on:     output.fetch(:start_on),
          )
        end
      end
      redirect_to group_event_path(params[:group_id], event_slug)
    else
      @event = params[:event]
        .slice(:name, :description, :lease_on, :start_on, :end_on, :return_on, :troop_slug, :leaser_name, :leaser_email, :leaser_phone)
      render action: :new
    end
  end

  def edit
    set_group
    @event = Scoutinv.new.find_event(group_slug: @group.fetch(:group_slug), event_slug: params[:id])
    render
  end

  def update
    set_group
    @result = EventSchema.call(params[:event].to_h)
    if @result.success?
      output     = @result.output
      scoutinv   = Scoutinv.new
      DB.transaction do
        scoutinv.change_event_details(
          group_slug:   @group.fetch(:group_slug),
          event_slug:   params[:id],

          description:  output.fetch(:description) || "",
          end_on:       output.fetch(:end_on),
          lease_on:     output.fetch(:lease_on),
          leaser_email: output.fetch(:leaser_email),
          leaser_name:  output.fetch(:leaser_name),
          leaser_phone: output.fetch(:leaser_phone),
          name:         output.fetch(:name),
          return_on:    output.fetch(:return_on),
          start_on:     output.fetch(:start_on),
          troop_slug:   output.fetch(:troop_slug),
        )
      end
      redirect_to group_event_path(params[:group_id], params[:id])
    else
      @event = params[:event]
        .slice(:name, :description, :lease_on, :start_on, :end_on, :return_on, :troop_slug, :leaser_name, :leaser_email, :leaser_phone)
      render action: :edit
    end
  end

  def show
    set_group
    scoutinv = Scoutinv.new
    @event = scoutinv.find_event(group_slug: params[:group_id], event_slug: params[:id])

    @reservations = scoutinv.find_event_reservations(group_slug: @event.fetch(:group_slug), event_slug: @event.fetch(:event_slug))
    @reservations = @reservations.map do |reservation|
      reservation[:image_paths] = reservation.fetch(:blob_slugs).map do |blob_slug|
        blob_path(blob_slug, format: "jpg", variant: "small", fallback: true)
      end

      reservation
    end

    render
  end

  private

  def set_group
    @group = Scoutinv.new.find_group(params[:group_id])
  end
end
