class Admin::BulletinPostsController < Admin::ApplicationController
  before_action :set_post, only: [:approve, :destroy]

  # FIFO review queue — oldest submissions first.
  def index
    @posts = BulletinPost.pending
                         .includes(:totem)
                         .order(created_at: :asc)
  end

  def approve
    @post.update!(status: "approved")
    redirect_to admin_bulletin_posts_path, notice: "Posted to #{@post.totem.name} board."
  end

  def destroy
    @post.destroy
    redirect_to admin_bulletin_posts_path, notice: "Post deleted."
  end

  private

  def set_post
    @post = BulletinPost.find(params[:id])
  end
end
