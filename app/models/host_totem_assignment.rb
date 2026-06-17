class HostTotemAssignment < ApplicationRecord
  belongs_to :host_user, class_name: "User"
  belongs_to :totem
  belongs_to :assigned_by_admin, class_name: "User", optional: true

  enum :role, { host: "host", totem_admin: "totem_admin" }, prefix: :role

  validates :host_user_id, uniqueness: { scope: :totem_id }

  before_create { self.assigned_at ||= Time.current }
end
