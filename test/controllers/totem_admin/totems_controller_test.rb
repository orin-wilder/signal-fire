require "test_helper"

class TotemAdmin::TotemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @totem_admin = users(:totem_admin_user)
    @main        = totems(:main_totem)
    @secondary   = totems(:secondary_totem)
  end

  test "redirects when not signed in" do
    get totem_admin_totems_path
    assert_redirected_to sign_in_path
  end

  test "redirects a plain signed-in user without a totem_admin assignment" do
    sign_in(users(:regular_user))
    get totem_admin_totems_path
    assert_redirected_to sign_in_path
  end

  test "redirects a host (role: host) without a totem_admin assignment" do
    sign_in(users(:host_user))
    get totem_admin_totems_path
    assert_redirected_to sign_in_path
  end

  test "totem admin sees only their moderated totems" do
    sign_in(@totem_admin)
    get totem_admin_totems_path
    assert_response :success
    assert_select "h1", text: /your totems/i
    assert_match @main.name, response.body
    assert_no_match(/#{@secondary.name}/, response.body)
  end

  test "super admin sees all totems" do
    sign_in(users(:admin_user))
    get totem_admin_totems_path
    assert_response :success
    assert_match @main.name, response.body
    assert_match @secondary.name, response.body
  end

  private

  def sign_in(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
  end
end
