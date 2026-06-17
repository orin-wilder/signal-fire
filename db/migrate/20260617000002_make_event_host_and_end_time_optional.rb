class MakeEventHostAndEndTimeOptional < ActiveRecord::Migration[8.1]
  # Phase 2 (unify the data model): Event becomes the single board record, so it
  # must hold board submissions that have no host (anonymous/visitor) and no
  # explicit end time. host_user_id/end_time become nullable; submitter_ip and
  # submitter_email carry the anonymous-submission metadata that lived on
  # bulletin_posts (email is for the optional "notify me when approved" path).
  # Existing host/admin events keep both values, so nothing changes for them.
  def change
    change_column_null :events, :host_user_id, true
    change_column_null :events, :end_time, true

    add_column :events, :submitter_ip, :string
    add_column :events, :submitter_email, :string
  end
end
