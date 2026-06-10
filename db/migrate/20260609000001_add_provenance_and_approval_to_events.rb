class AddProvenanceAndApprovalToEvents < ActiveRecord::Migration[8.1]
  def change
    # Additive + backfilled via defaults: every existing row becomes
    # host / published, i.e. behaviorally unchanged. Future AI-sourced events
    # use the other values to stay off public surfaces until approved.
    add_column :events, :provenance, :string, null: false, default: "host"
    add_column :events, :approval_state, :string, null: false, default: "published"
    add_index  :events, :approval_state
  end
end
