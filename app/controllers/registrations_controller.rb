# frozen_string_literal: true
require "types"
require "ostruct"

class RegistrationsController < ApplicationController
  RegistrationSchema = Dry::Schema.Params do
    required(:name).filled(Types::StrippedString)
    required(:admin_name).filled(Types::StrippedString)
    required(:admin_email).filled(Types::StrippedString, format?: /\A[^@]+@.+[.][a-z]{2,}\z/i)
    required(:admin_phone).filled(Types::StrippedString)
    required(:admin_password).filled(Types::StrippedString, min_size?: 8)
  end

  def new
    @registration = Hash.new
    render
  end

  def create
    @result = RegistrationSchema.call(params[:registration].to_h)
    if @result.success?
      group_slug = DB.transaction do
        output = @result.output
        Scoutinv.new.register_group(
          name:           output[:name],
          admin_name:     output[:admin_name],
          admin_email:    output[:admin_email],
          admin_phone:    output[:admin_phone],
          admin_password: output[:admin_passowrd],
        )
      end

      redirect_to group_path(group_slug)
    else
      @registration = params[:registration]
        .slice(:name, :admin_name, :admin_email, :admin_phone, :admin_password)
      render action: :new
    end
  end
end
