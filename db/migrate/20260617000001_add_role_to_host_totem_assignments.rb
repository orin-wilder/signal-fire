class AddRoleToHostTotemAssignments < ActiveRecord::Migration[8.1]
  def change
    add_column :host_totem_assignments, :role, :string, null: false, default: "host"
  end
end
