class Admin::BulletinPostsController < Admin::ApplicationController
  before_action :set_post, only: [:approve, :edit, :update, :destroy]

  def index
    # FIFO review queue — oldest pending submissions first.
    @pending_posts = BulletinPost.pending
                                 .includes(:totem)
                                 .order(created_at: :asc)

    # Live board content — approved posts, soonest upcoming first then past.
    @approved_posts = BulletinPost.approved
                                  .includes(:totem)
                                  .order(starts_at: :desc)
  end

  def approve
    @post.update!(status: "approved")
    redirect_to admin_bulletin_posts_path, notice: "Posted to #{@post.totem.name} board."
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to admin_bulletin_posts_path, notice: "Post updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to admin_bulletin_posts_path, notice: "Post deleted."
  end

  private

  def set_post
    @post = BulletinPost.find(params[:id])
  end

  # Permit the editable fields plus the separate date/time inputs the form uses
  # to build starts_at. Cadence is cleared when the post isn't recurring.
  def post_params
    permitted = params.require(:bulletin_post)
                      .permit(:title, :description, :recurring, :recurrence_cadence, :date, :time, :source_url)

    date = permitted.delete(:date)
    time = permitted.delete(:time)
    composed = compose_starts_at(date, time)
    permitted[:starts_at] = composed if composed || (date.present? || time.present?)

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
