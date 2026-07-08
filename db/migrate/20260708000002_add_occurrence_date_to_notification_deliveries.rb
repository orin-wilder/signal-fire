class AddOccurrenceDateToNotificationDeliveries < ActiveRecord::Migration[8.1]
  # Dedup was previously enforced only by a model validation over a non-unique
  # index — racy (concurrent workers double-send) and occurrence-blind (weekly
  # reminders after the first were suppressed). Replace with a unique index
  # keyed on the occurrence. NULLS NOT DISTINCT keeps the once-ever semantics
  # for types that don't carry an occurrence (new_event, cancelled,
  # first_stranger).
  def up
    add_column :notification_deliveries, :occurrence_date, :date

    # Remove duplicates left by the check-then-create race (keep the earliest
    # row) so the unique index can build.
    execute <<~SQL
      DELETE FROM notification_deliveries a
      USING notification_deliveries b
      WHERE a.user_id = b.user_id
        AND a.event_id = b.event_id
        AND a.notification_type = b.notification_type
        AND a.id > b.id
    SQL

    remove_index :notification_deliveries, column: [ :user_id, :event_id, :notification_type ]
    add_index :notification_deliveries,
      [ :user_id, :event_id, :notification_type, :occurrence_date ],
      unique: true, nulls_not_distinct: true,
      name: "idx_notification_deliveries_dedup"
  end

  def down
    remove_index :notification_deliveries, name: "idx_notification_deliveries_dedup"
    add_index :notification_deliveries, [ :user_id, :event_id, :notification_type ]
    remove_column :notification_deliveries, :occurrence_date
  end
end
