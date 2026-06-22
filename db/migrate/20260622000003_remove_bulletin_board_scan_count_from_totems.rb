class RemoveBulletinBoardScanCountFromTotems < ActiveRecord::Migration[8.1]
  # Dead column from the retired bulletin board — never read or written by app
  # code, and superseded by the analytics_events table for scan counts.
  def change
    remove_column :totems, :bulletin_board_scan_count, :integer, default: 0, null: false
  end
end
