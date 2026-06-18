class AddShortCodeToTotems < ActiveRecord::Migration[8.1]
  # Phase 6: a short numeric code printed on the physical totem ("/g/42"), so a
  # passer-by can type it instead of scanning. Stored as a string (leading zeros;
  # length can grow 2→3 digits later with no migration). Globally unique.
  def up
    add_column :totems, :short_code, :string
    add_index  :totems, :short_code, unique: true

    # Backfill existing totems with unique 2-digit codes.
    Totem.reset_column_information
    Totem.where(short_code: nil).find_each do |totem|
      code = nil
      loop do
        code = rand(100).to_s.rjust(2, "0")
        break unless Totem.exists?(short_code: code)
      end
      totem.update_columns(short_code: code)
    end
  end

  def down
    remove_column :totems, :short_code
  end
end
