class AddIndexesToAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    # Standalone occurred_at index for the retention prune sweep — the existing
    # composite indexes lead with name/totem_id/event_id, so they can't serve a
    # bare `occurred_at < ?` delete efficiently.
    add_index :analytics_events, :occurred_at

    # Unique-visitor counts group/distinct on visitor_hash, which is otherwise
    # unindexed.
    add_index :analytics_events, :visitor_hash
  end
end
