require "test_helper"

class UserTest < ActiveSupport::TestCase
  # email auth validations
  test "valid email auth user" do
    user = User.new(email: "new@example.com", password: "password123", name: "New", auth_method: :email)
    assert user.valid?
  end

  test "email auth requires email" do
    user = User.new(password: "password123", name: "New", auth_method: :email)
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "email auth requires valid email format" do
    user = User.new(email: "not-an-email", password: "password123", name: "New", auth_method: :email)
    assert_not user.valid?
    assert user.errors[:email].any?
  end

  test "email auth requires unique email" do
    user = User.new(email: users(:host_user).email, password: "password123", name: "New", auth_method: :email)
    assert_not user.valid?
    assert user.errors[:email].any?
  end

  test "email is downcased before save" do
    user = User.create!(email: "UPPER@EXAMPLE.COM", password: "password123", name: "U", auth_method: :email)
    assert_equal "upper@example.com", user.email
  end

  test "password must be at least 8 characters" do
    user = User.new(email: "new@example.com", password: "short", name: "New", auth_method: :email)
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  test "password validation skipped for google users" do
    user = User.new(google_uid: "uid_xyz", email: "g@example.com", name: "G", auth_method: :google)
    assert user.valid?
  end

  test "google uid must be unique" do
    user = User.new(google_uid: users(:google_user).google_uid, name: "Dup", auth_method: :google)
    assert_not user.valid?
    assert user.errors[:google_uid].any?
  end

  test "google user without email is valid" do
    user = User.new(google_uid: "unique_uid_999", name: "No Email", auth_method: :google)
    assert user.valid?
  end

  test "email_auth? returns true for email auth method" do
    assert users(:host_user).email_auth?
  end

  test "email_auth? returns false for google auth method" do
    assert_not users(:google_user).email_auth?
  end

  test "authenticate returns user with correct password" do
    user = users(:host_user)
    assert user.authenticate("password123")
  end

  test "authenticate returns false with wrong password" do
    user = users(:host_user)
    assert_not user.authenticate("wrongpassword")
  end

  # ── Role / authorization API ──────────────────────────────────────────────

  setup do
    @main      = totems(:main_totem)
    @secondary = totems(:secondary_totem)
  end

  # super_admin? / is_admin

  test "super_admin? mirrors is_admin" do
    assert users(:admin_user).super_admin?
    assert_not users(:host_user).super_admin?
    assert_not users(:totem_admin_user).super_admin?
  end

  # totem_role_for

  test "totem_role_for returns :super_admin for admins on any totem" do
    assert_equal :super_admin, users(:admin_user).totem_role_for(@main)
    assert_equal :super_admin, users(:admin_user).totem_role_for(@secondary)
  end

  test "totem_role_for returns :totem_admin for a totem admin on their totem" do
    assert_equal :totem_admin, users(:totem_admin_user).totem_role_for(@main)
  end

  test "totem_role_for returns :host for an assigned host" do
    assert_equal :host, users(:host_user).totem_role_for(@main)
  end

  test "totem_role_for returns nil with no assignment" do
    assert_nil users(:host_user).totem_role_for(@secondary)
    assert_nil users(:regular_user).totem_role_for(@main)
  end

  # moderated_totem_ids

  test "moderated_totem_ids returns all totem ids for super admins" do
    assert_equal Totem.ids.sort, users(:admin_user).moderated_totem_ids.sort
  end

  test "moderated_totem_ids returns only totem_admin assignments" do
    assert_equal [@main.id], users(:totem_admin_user).moderated_totem_ids
  end

  test "moderated_totem_ids is empty for a plain host" do
    assert_empty users(:host_user).moderated_totem_ids
  end

  # totem_admin_of? / can_moderate_totem?

  test "totem_admin_of? is true only for the assigned totem" do
    assert users(:totem_admin_user).totem_admin_of?(@main)
    assert_not users(:totem_admin_user).totem_admin_of?(@secondary)
    assert_not users(:host_user).totem_admin_of?(@main)
  end

  test "can_moderate_totem? for super admin, totem admin, not host or plain user" do
    assert users(:admin_user).can_moderate_totem?(@secondary)
    assert users(:totem_admin_user).can_moderate_totem?(@main)
    assert_not users(:totem_admin_user).can_moderate_totem?(@secondary)
    assert_not users(:host_user).can_moderate_totem?(@main)
    assert_not users(:regular_user).can_moderate_totem?(@main)
  end

  # can_auto_publish_on?

  test "can_auto_publish_on? true for super admin on any totem" do
    assert users(:admin_user).can_auto_publish_on?(@secondary)
  end

  test "can_auto_publish_on? true for totem admin without a host profile" do
    admin = users(:totem_admin_user)
    assert_nil admin.host_profile
    assert admin.can_auto_publish_on?(@main)
  end

  test "can_auto_publish_on? true for host with active profile" do
    assert users(:host_user).can_auto_publish_on?(@main)
  end

  test "can_auto_publish_on? false for host whose profile is not active" do
    host = users(:deactivated_host_user)
    HostTotemAssignment.create!(host_user: host, totem: @main, role: :host)
    assert_not host.can_auto_publish_on?(@main)
  end

  test "can_auto_publish_on? false for plain signed-in user" do
    assert_not users(:regular_user).can_auto_publish_on?(@main)
  end

  test "can_auto_publish_on? false on a totem with no assignment" do
    assert_not users(:host_user).can_auto_publish_on?(@secondary)
  end

  # can_manage_hosts_on?

  test "can_manage_hosts_on? for super admin and totem admin only" do
    assert users(:admin_user).can_manage_hosts_on?(@secondary)
    assert users(:totem_admin_user).can_manage_hosts_on?(@main)
    assert_not users(:totem_admin_user).can_manage_hosts_on?(@secondary)
    assert_not users(:host_user).can_manage_hosts_on?(@main)
  end
end
