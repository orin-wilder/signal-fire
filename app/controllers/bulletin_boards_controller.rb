class BulletinBoardsController < ApplicationController
  layout "bulletin_board"

  CITY_SLUG = "stpete".freeze

  before_action :set_totem, except: [:index]

  # Directory of active boards in the city — a board is "active" when it has at
  # least one currently-upcoming approved post (the BulletinPost.upcoming scope).
  def index
    active_totem_ids = BulletinPost.upcoming.reorder(nil).distinct.pluck(:totem_id)
    @totems = Totem.for_city(CITY_SLUG)
                   .where(id: active_totem_ids)
                   .order(:name)
  end

  # Public board for one totem. Anonymous, no auth.
  def show
    @totem.increment!(:bulletin_board_scan_count)

    @upcoming_posts = @totem.bulletin_posts.upcoming
    @past_posts     = @totem.bulletin_posts.past
    @post           = @totem.bulletin_posts.new
  end

  def create
    @post = @totem.bulletin_posts.new(post_params)
    @post.status       = "pending"
    @post.submitter_ip = request.remote_ip

    if @post.save
      respond_to do |format|
        format.turbo_stream # create.turbo_stream.erb → swap form for success
        format.html { redirect_to bulletin_board_path(@totem.slug), notice: "Thanks — we'll take a look." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html do
          @upcoming_posts = @totem.bulletin_posts.upcoming
          @past_posts     = @totem.bulletin_posts.past
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_totem
    @totem = Totem.find_by!(slug: params[:totem_slug])
  rescue ActiveRecord::RecordNotFound
    render "not_found", status: :not_found
  end

  # Permit the post fields plus the separate date/time inputs the form uses to
  # build starts_at. starts_at itself is composed here, not mass-assigned.
  def post_params
    permitted = params.require(:bulletin_post)
                      .permit(:title, :description, :recurring, :recurrence_cadence, :date, :time)

    date = permitted.delete(:date)
    time = permitted.delete(:time)
    permitted[:starts_at] = compose_starts_at(date, time)

    # Cadence is only meaningful when recurring; drop it otherwise.
    permitted[:recurrence_cadence] = nil unless ActiveModel::Type::Boolean.new.cast(permitted[:recurring])

    permitted
  end

  def compose_starts_at(date, time)
    return nil if date.blank? || time.blank?

    Time.find_zone("America/New_York").parse("#{date} #{time}")
  rescue ArgumentError
    nil
  end
end
