module ApplicationHelper
  def product_location(product)
    [:building, :room, :aisle, :bin].map do |key|
      product[key]
    end.reject(&:blank?).join(" / ")
  end
end
