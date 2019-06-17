class HomeController < ApplicationController
  def index
    @groups = Scoutinv.new.find_accessible_groups_of_user(user_slug: "svnryv")
    @last_date = @groups
      .map{|group| group.fetch(:events)}
      .flatten
      .map{|event| event.fetch(:return_on)}
      .max
    @last_date = 1.month.from_now.to_date unless @last_date

    dates = @groups.map do |group|
      group.fetch(:events).each_with_object(Hash.new) do |event, memo|
        (event.fetch(:lease_on) .. event.fetch(:return_on)).each do |date|
          memo[date] ||= []
          memo[date] << {
            group_slug:  group.fetch(:group_slug),
            troop_slug:  event.fetch(:troop).fetch(:troop_slug),
            event_slug:  event.fetch(:event_slug),
            group_name:  group.fetch(:name),
            event_name:  event.fetch(:name),
            leaser_name: event.fetch(:leaser_name) || event.fetch(:troop).fetch(:name),
          }
        end
      end
    end

    if dates.any?
      min_date, max_date = dates.map(&:keys).flatten.minmax
      @dates = (min_date .. max_date).map do |date|
        result = dates
          .select{|hash| hash.keys.include?(date)}
          .map{|hash| hash[date]}
          .flatten

        [date, result]
      end.to_h
    else
      @dates = Hash.new
    end

    render
  end
end
