module ApplicationHelper
  def product_location(product)
    [:building, :room, :aisle, :bin].map do |key|
      product[key]
    end.reject(&:blank?).join(" / ")
  end

  def render_errors(errors)
    render partial: "shared/errors", locals: { errors: errors || {} }
  end
end
