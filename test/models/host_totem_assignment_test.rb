require "test_helper"

class HostTotemAssignmentTest < ActiveSupport::TestCase
  def build_assignment(overrides = {})
    HostTotemAssignment.new({
      host_user: users(:host_user),
      totem: totems(:secondary_totem)
    }.merge(overrides))
  end

  test "assigned_at is auto-set before create" do
    assignment = build_assignment
    assignment.save!
    assert_not_nil assignment.assigned_at
  end

  test "duplicate host_user + totem is invalid" do
    HostTotemAssignment.create!(host_user: users(:host_user), totem: totems(:secondary_totem))
    duplicate = build_assignment
    assert_not duplicate.valid?
    assert duplicate.errors[:host_user_id].any?
  end

  test "same host can be assigned to different totems" do
    HostTotemAssignment.create!(host_user: users(:host_user), totem: totems(:secondary_totem))
    other = build_assignment(totem: totems(:inactive_totem))
    assert other.valid?
  end

  test "different hosts can be assigned to the same totem" do
    HostTotemAssignment.create!(host_user: users(:host_user), totem: totems(:secondary_totem))
    other = build_assignment(host_user: users(:regular_user))
    assert other.valid?
  end

  # ── role ──────────────────────────────────────────────────────────────────

  test "role defaults to host" do
    assignment = HostTotemAssignment.create!(host_user: users(:host_user), totem: totems(:secondary_totem))
    assert_equal "host", assignment.role
    assert assignment.role_host?
  end

  test "role can be set to totem_admin" do
    assignment = HostTotemAssignment.create!(
      host_user: users(:regular_user), totem: totems(:secondary_totem), role: :totem_admin
    )
    assert assignment.role_totem_admin?
    assert_not assignment.role_host?
  end

  test "enum exposes both role values" do
    assert_equal({ "host" => "host", "totem_admin" => "totem_admin" }, HostTotemAssignment.roles)
  end

  test "invalid role raises" do
    assert_raises(ArgumentError) do
      build_assignment(role: :nonsense)
    end
  end
end
