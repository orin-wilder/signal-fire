class CitiesController < ApplicationController
  def show
    @city_slug = params[:city_slug]
    @totems = Totem
      .city_board_visible
      .for_city(@city_slug)
      .includes(
        :empty_totem_email_captures,
        hosts: :host_profile,
        events: :anonymous_check_in_count
      )
      .order(:name)
    AnalyticsService.track("city_board_viewed", city_slug: @city_slug)
  end
end
