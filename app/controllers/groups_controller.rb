class GroupsController < ApplicationController
  Group = Struct.new(:slug, :name, :troops, :admin_name, :admin_email, :admin_phone)
  Troop = Struct.new(:slug, :name, :members)
  User  = Struct.new(:slug, :name, :email, :phone)

  def show
    @group = Scoutinv.new.find_group(params[:id])
  end
end
