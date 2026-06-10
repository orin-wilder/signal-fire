class CreateScoutRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :scout_runs do |t|
      t.references :totem, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending" # pending | complete | failed
      t.text :error
      t.timestamps
    end
  end
end
