class FlipEventsApprovalStateDefault < ActiveRecord::Migration[8.1]
  def change
    # Safe-by-default: a row that doesn't say otherwise lands in review instead
    # of on public surfaces. Every legitimate create path sets the state
    # explicitly (host form, admin console, submission funnel, scout promote).
    change_column_default :events, :approval_state, from: "published", to: "pending_review"

    # Notification fan-out queries host_follows by host_user_id; only the
    # (user_id, host_user_id) composite existed.
    add_index :host_follows, :host_user_id

    # The same email could be captured for a totem once per page visit.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          DELETE FROM empty_totem_email_captures a
          USING empty_totem_email_captures b
          WHERE a.totem_id = b.totem_id
            AND a.email = b.email
            AND a.id > b.id
        SQL
      end
    end
    add_index :empty_totem_email_captures, [ :totem_id, :email ], unique: true
  end
end
