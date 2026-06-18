class Totems::EventPhotoExtractionsController < ApplicationController
  before_action :set_totem

  # Vision calls cost money on every request, so the public photo path is
  # throttled per IP (tighter than text submissions). Mirrors the submission
  # throttle but keyed separately.
  THROTTLE_LIMIT  = 5
  THROTTLE_WINDOW = 1.hour

  # POST /t/:slug/events/from_photo — read an event off a flyer photo and return
  # JSON to PRE-FILL the submission form. The image is never persisted; the
  # extracted data still flows through the normal create path + approval gate.
  def create
    if throttled?
      return render json: { error: "That's a lot of photos — give it a little while." }, status: :too_many_requests
    end

    image = params[:image].to_s
    unless image.start_with?("data:image/")
      return render json: { error: "Attach a photo of the event." }, status: :unprocessable_entity
    end

    result = Ai::EventImageExtractor.call(image_data_url: image)
    record_attempt!

    if result.ok
      render json: { event: result.event }
    else
      render json: { error: "Couldn't read that photo — try typing it in." }, status: :unprocessable_entity
    end
  end

  private

  def set_totem
    @totem = Totem.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def throttled?
    attempt_count >= THROTTLE_LIMIT
  end

  def record_attempt!
    Rails.cache.write(throttle_key, attempt_count + 1, expires_in: THROTTLE_WINDOW)
  end

  def attempt_count
    Rails.cache.read(throttle_key).to_i
  end

  def throttle_key
    "event_photo:#{request.remote_ip}"
  end
end
