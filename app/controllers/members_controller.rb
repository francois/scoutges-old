class MembersController < ApplicationController
  MemberSchema = Dry::Schema.Params do
    required(:email).filled(Types::StrippedString, format?: /\A[^@]+@.+[.][a-z]{2,}\z/i)
    required(:name).filled(Types::StrippedString)
  end

  def create
    result = MemberSchema.call(params[:member].to_h)

    if result.success?
      scoutinv = Scoutinv.new
      output = result.output

      DB.transaction do
        scoutinv.register_user(
          email:    output.fetch(:email),
          name:     output.fetch(:name),
          password: SecureRandom.alphanumeric(64),
        )

        scoutinv.attach_user_to_group(
          group_slug: params[:group_id],
          email:      output.fetch(:email),
        )
      end
    end

    redirect_to group_path(params[:group_id])
  end
end
