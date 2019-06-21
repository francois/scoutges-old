class EnrollmentsController < ApplicationController
  EnrollmentSchema = Dry::Schema.Params do
    required(:troop_slug).filled(:string)
    required(:email).filled(:string)
  end

  RemoveEnrollmentSchema = Dry::Schema.Params do
    required(:troop_slug).filled(:string)
    required(:email).filled(:string)
  end

  def create
    result = EnrollmentSchema.call(params[:enrollment].to_h)
    if result.success?
      output = result.output
      DB.transaction do
        Scoutinv.new.attach_user_to_troop(
          email:      output.fetch(:email),
          group_slug: params[:group_id],
          troop_slug: output.fetch(:troop_slug),
        )
      end
    end

    redirect_to group_path(params[:group_id])
  end

  def destroy
    result = RemoveEnrollmentSchema.call(params[:enrollment].to_h)
    if result.success?
      output = result.output
      DB.transaction do
        Scoutinv.new.detach_user_from_troop(
          email:      output.fetch(:email),
          group_slug: params[:group_id],
          troop_slug: output.fetch(:troop_slug),
        )
      end
    end

    redirect_to group_path(params[:group_id])
  end
end
