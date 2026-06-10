class AddSourceUrlAndSourceToBulletinPosts < ActiveRecord::Migration[8.1]
  def change
    # B1: optional link on a post (rendered only after approval).
    add_column :bulletin_posts, :source_url, :string

    # Q4: provenance tag, surfaced in admin only for now. Every existing/anonymous
    # submission is a public_submission; reserved values: admin_added, scouted.
    add_column :bulletin_posts, :source, :string, null: false, default: "public_submission"
  end
end
