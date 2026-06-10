class CreateScoutedEventCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :scouted_event_candidates do |t|
      t.references :scout_run, null: false, foreign_key: true
      t.string  :title
      t.text    :description
      t.string  :event_date # raw AI string, e.g. "2026-06-13"
      t.string  :event_time # raw AI string, nullable
      t.string  :location
      t.string  :source_url
      t.string  :organizer
      t.boolean :ignored, null: false, default: false
      # Links to records this candidate was promoted into (a candidate may be
      # added to a totem Event and/or a BulletinPost). Both nullable.
      t.references :event, foreign_key: true
      t.references :bulletin_post, foreign_key: true
      t.timestamps
    end
  end
end
