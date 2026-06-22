class CreateAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_events do |t|
      t.string :name, null: false
      t.bigint :totem_id
      t.bigint :event_id
      t.bigint :user_id
      t.string :source
      t.string :visitor_hash
      t.datetime :occurred_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :analytics_events, [ :name, :occurred_at ]
    add_index :analytics_events, [ :totem_id, :occurred_at ]
    add_index :analytics_events, [ :event_id, :occurred_at ]
  end
end
