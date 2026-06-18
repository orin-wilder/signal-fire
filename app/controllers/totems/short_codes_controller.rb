class Totems::ShortCodesController < ApplicationController
  # GET /g/:code — the typed-entry shortcut printed on a physical totem. Resolves
  # the numeric code to its totem and 301s to the canonical board. A dedicated
  # /g/ prefix (not /t/:slug) is required — a bare number is a valid slug, so the
  # two would be ambiguous. source=short_code lets the board's analytics tell
  # typed-code entry apart from a QR scan.
  def show
    totem = Totem.find_by(short_code: params[:code])
    return head :not_found unless totem

    redirect_to totem_board_path(totem.slug, source: :short_code), status: :moved_permanently
  end
end
