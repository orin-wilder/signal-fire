class AddBulletinBoardScanCountToTotems < ActiveRecord::Migration[8.1]
  def change
    add_column :totems, :bulletin_board_scan_count, :integer, null: false, default: 0
  end
end
