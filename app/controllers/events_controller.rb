# frozen_string_literal: true
require "types"

class EventsController < ApplicationController
  RegisterEventSchema = Dry::Schema.Params do
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

  def new
    set_group
    @event = Hash.new
    render
  end

  def create
    set_group
    @result = RegisterEventSchema.call(params[:event].to_h)
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

  def show
    set_group
    @event = Scoutinv.new.find_event(group_slug: params[:group_id], event_slug: params[:id])
    render
  end

  private

  def set_group
    @group = Scoutinv.new.find_group(params[:group_id])
  end
end
