class TroopsController < ApplicationController
  TroopSchema = Dry::Schema.Params do
    required(:name).filled(:string)
  end

  def create
    result = TroopSchema.call(params[:registration].to_h)
    if result.success?
      DB.transaction do
        Scoutinv.new.register_troop(
          group_slug: params[:group_id],
          name:       result.output.fetch(:name),
        )
      end
    end

    redirect_to group_path(params[:group_id])
  end
end
