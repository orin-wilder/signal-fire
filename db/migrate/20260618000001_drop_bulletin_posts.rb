class DropBulletinPosts < ActiveRecord::Migration[8.1]
  # Final bulletin retirement. Parity verified in prod (every bulletin_post is
  # backfilled into Event; all scouted candidates repointed), so the legacy table
  # and its FK on scouted_event_candidates are removed. `down` recreates the
  # structure only (the data is gone for good).
  def up
    remove_column :scouted_event_candidates, :bulletin_post_id
    drop_table :bulletin_posts
  end

  def down
    create_table :bulletin_posts do |t|
      t.string     :title, null: false
      t.string     :description, null: false
      t.datetime   :starts_at, null: false
      t.string     :status, default: "pending", null: false
      t.string     :source, default: "public_submission", null: false
      t.string     :source_url
      t.boolean    :recurring, default: false, null: false
      t.string     :recurrence_cadence
      t.string     :submitter_ip
      t.references :totem, null: false
      t.timestamps
    end
    add_index :bulletin_posts, :starts_at
    add_index :bulletin_posts, :status

    add_reference :scouted_event_candidates, :bulletin_post
  end
end
