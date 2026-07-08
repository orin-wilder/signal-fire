class EmptyTotemEmailCapturesController < ApplicationController
  def create
    totem = Totem.find_by!(id: params[:totem_id])
    capture = EmptyTotemEmailCapture.new(email: params[:email]&.strip, totem: totem)

    if capture.save || capture.errors.of_kind?(:email, :taken)
      # A repeat signup is a success from the visitor's point of view.
      redirect_to totem_board_path(totem.slug), notice: "Got it! We'll let you know when events are happening here."
    else
      redirect_to totem_board_path(totem.slug), alert: "Please enter a valid email address."
    end
  end
end
