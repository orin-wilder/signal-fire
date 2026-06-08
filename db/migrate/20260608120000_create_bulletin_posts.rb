class CreateBulletinPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :bulletin_posts do |t|
      t.references :totem, null: false, foreign_key: true
      t.string   :title, null: false
      t.datetime :starts_at, null: false
      t.string   :description, null: false
      t.boolean  :recurring, null: false, default: false
      t.string   :recurrence_cadence
      t.string   :status, null: false, default: "pending"
      t.string   :submitter_ip

      t.timestamps
    end

    add_index :bulletin_posts, :status
    add_index :bulletin_posts, :starts_at
  end
end
