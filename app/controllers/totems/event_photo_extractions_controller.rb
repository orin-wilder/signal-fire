class Totems::EventPhotoExtractionsController < ApplicationController
  before_action :set_totem

  # Vision calls cost money on every request, so the public photo path is
  # throttled per IP (tighter than text submissions). Mirrors the submission
  # throttle but keyed separately.
  THROTTLE_LIMIT  = 5
  THROTTLE_WINDOW = 1.hour

  # Cap what we forward to the paid vision model. Base64 inflates ~4/3, so this
  # allows roughly a 6 MB photo — far above any reasonable flyer shot.
  MAX_IMAGE_BYTES = 8.megabytes

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

    if image.bytesize > MAX_IMAGE_BYTES
      return render json: { error: "That photo is too large — try a smaller one." }, status: 413
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
  rescue StandardError => e
    # Fail open: a cache-backend outage must not 500 the photo path. Mirrors the
    # throttle handling in Totems::EventSubmissionsController.
    Rails.logger.warn("[event_photo] throttle write failed: #{e.class}: #{e.message}")
  end

  def attempt_count
    Rails.cache.read(throttle_key).to_i
  rescue StandardError => e
    Rails.logger.warn("[event_photo] throttle read failed: #{e.class}: #{e.message}")
    0
  end

  def throttle_key
    "event_photo:#{request.remote_ip}"
  end
end
