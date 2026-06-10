class AddShortDescriptionToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :short_description, :string
  end
end
