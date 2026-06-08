require "test_helper"

class Admin::TotemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @totem = totems(:main_totem)
  end

  # ── Auth guard ────────────────────────────────────────────────────────────

  test "GET /admin/totems redirects to login when not signed in" do
    get admin_totems_path
    assert_redirected_to admin_login_path
  end

  test "GET /admin/totems redirects to login for non-admin host" do
    post host_login_path, params: { email: users(:host_user).email, password: "password123" }
    get admin_totems_path
    assert_redirected_to admin_login_path
  end

  # ── Index ─────────────────────────────────────────────────────────────────

  test "GET /admin/totems lists totems for admin" do
    sign_in_as_admin
    get admin_totems_path
    assert_response :success
    assert_select "h1", text: /totems/i
    assert_select "td", text: @totem.name
  end

  test "GET /admin/totems filters by search query" do
    sign_in_as_admin
    get admin_totems_path, params: { q: @totem.name }
    assert_response :success
    assert_select "td", text: @totem.name
    assert_select "td", text: totems(:inactive_totem).name, count: 0
  end

  test "GET /admin/totems shows empty state when no results match" do
    sign_in_as_admin
    get admin_totems_path, params: { q: "zzznomatch" }
    assert_response :success
    assert_select "p", text: /no totems match/i
  end

  # ── New / Create ──────────────────────────────────────────────────────────

  test "GET /admin/totems/new renders form" do
    sign_in_as_admin
    get new_admin_totem_path
    assert_response :success
    assert_select "form"
  end

  test "POST /admin/totems creates totem and redirects" do
    sign_in_as_admin
    assert_difference "Totem.count", 1 do
      post admin_totems_path, params: {
        totem: { name: "Beach Lawn", location: "Crescent Lake", sublocation: "East side", active: true }
      }
    end
    assert_redirected_to admin_totems_path
    assert_equal "Beach Lawn", Totem.last.name
  end

  test "POST /admin/totems without name renders new with errors" do
    sign_in_as_admin
    assert_no_difference "Totem.count" do
      post admin_totems_path, params: {
        totem: { name: "", location: "Somewhere", active: false }
      }
    end
    assert_response :unprocessable_entity
  end

  test "POST /admin/totems without location renders new with errors" do
    sign_in_as_admin
    assert_no_difference "Totem.count" do
      post admin_totems_path, params: {
        totem: { name: "Good Name", location: "", active: false }
      }
    end
    assert_response :unprocessable_entity
  end

  # ── Edit / Update ─────────────────────────────────────────────────────────

  test "GET /admin/totems/:id/edit renders form" do
    sign_in_as_admin
    get edit_admin_totem_path(@totem)
    assert_response :success
    assert_select "form"
  end

  test "PATCH /admin/totems/:id updates totem and redirects" do
    sign_in_as_admin
    patch admin_totem_path(@totem), params: {
      totem: { name: "Renamed Totem", location: @totem.location }
    }
    assert_redirected_to admin_totems_path
    assert_equal "Renamed Totem", @totem.reload.name
  end

  test "PATCH /admin/totems/:id with blank name renders edit with errors" do
    sign_in_as_admin
    patch admin_totem_path(@totem), params: {
      totem: { name: "", location: @totem.location }
    }
    assert_response :unprocessable_entity
  end

  test "PATCH /admin/totems/:id can toggle active status" do
    sign_in_as_admin
    patch admin_totem_path(@totem), params: {
      totem: { name: @totem.name, location: @totem.location, active: false }
    }
    assert_redirected_to admin_totems_path
    assert_not @totem.reload.active
  end

  test "PATCH /admin/totems/:id saves character_description and neighborhood" do
    sign_in_as_admin
    patch admin_totem_path(@totem), params: {
      totem: {
        name: @totem.name,
        location: @totem.location,
        character_description: "A shaded lawn for morning gatherings.",
        neighborhood: "Old Northeast"
      }
    }
    assert_redirected_to admin_totems_path
    @totem.reload
    assert_equal "A shaded lawn for morning gatherings.", @totem.character_description
    assert_equal "Old Northeast", @totem.neighborhood
  end

  test "PATCH /admin/totems/:id rejects character_description over 140 chars" do
    sign_in_as_admin
    patch admin_totem_path(@totem), params: {
      totem: {
        name: @totem.name,
        location: @totem.location,
        character_description: "x" * 141
      }
    }
    assert_response :unprocessable_entity
  end

  # ── Destroy ───────────────────────────────────────────────────────────────

  test "DELETE /admin/totems/:id destroys totem with no assignments" do
    sign_in_as_admin
    totem = Totem.create!(name: "Temp", location: "Somewhere", slug: "temp-totem", active: false)
    assert_difference "Totem.count", -1 do
      delete admin_totem_path(totem)
    end
    assert_redirected_to admin_totems_path
  end

  test "DELETE /admin/totems/:id also destroys dependent host_totem_assignments" do
    sign_in_as_admin
    totem = Totem.create!(name: "AssignedTotem", location: "Park", slug: "assigned-totem", active: true)
    HostTotemAssignment.create!(host_user: users(:host_user), totem: totem, assigned_at: Time.current)

    assert_difference ["Totem.count", "HostTotemAssignment.count"], -1 do
      delete admin_totem_path(totem)
    end
    assert_redirected_to admin_totems_path
  end

  # ── QR download ──────────────────────────────────────────────────────────

  test "GET /admin/totems/:id/qr sends a PNG file" do
    sign_in_as_admin
    get qr_admin_totem_path(@totem)
    assert_response :success
    assert_equal "image/png", response.content_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.headers["Content-Disposition"], "#{@totem.slug}-qr.png"
  end

  test "GET /admin/totems/:id/board_qr sends a board PNG file" do
    sign_in_as_admin
    get board_qr_admin_totem_path(@totem)
    assert_response :success
    assert_equal "image/png", response.content_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.headers["Content-Disposition"], "#{@totem.slug}-board-qr.png"
  end

  private

  def sign_in_as_admin
    post admin_login_path, params: { email: @admin.email, password: "password123" }
  end
end
