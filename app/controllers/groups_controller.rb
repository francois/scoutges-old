class GroupsController < ApplicationController
  def show
    @group = Scoutinv.new.find_group(params[:id])
  end
end
