# frozen_string_literal: true

class BlobsController < ApplicationController
  def show
    variant  = params.fetch(:variant, "original")
    fallback = params[:fallback] == "true"

    data, content_type = DatabaseBlobStorage.new
      .data_of(params[:id], variant: variant, fallback: fallback)

    if data
      send_data data, type: content_type, disposition: "inline"
    else
      send_file "public/placeholder.png", type: "image/png", disposition: "inline"
    end
  end

  def destroy
    DatabaseBlobStorage.new.delete(params[:id])
  end
end
