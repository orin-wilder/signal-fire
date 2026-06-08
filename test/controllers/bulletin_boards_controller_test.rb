require "test_helper"

class BulletinBoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @totem = totems(:main_totem)
  end

  # ── Show ───────────────────────────────────────────────────────────────────

  test "GET board renders for a valid totem slug without auth" do
    get bulletin_board_path(@totem.slug)
    assert_response :success
    assert_select "h1.bb-location", text: @totem.name
    assert_select "button.bb-cta", text: /add an event here/i
  end

  test "GET board increments scan count" do
    assert_difference -> { @totem.reload.bulletin_board_scan_count }, 1 do
      get bulletin_board_path(@totem.slug)
    end
  end

  test "GET board with unknown slug returns 404 in voice" do
    get bulletin_board_path("no-such-totem")
    assert_response :not_found
    assert_select "h1", text: /no board here/i
  end

  test "approved upcoming posts render, pending do not" do
    approved = @totem.bulletin_posts.create!(title: "Approved jam", starts_at: 2.days.from_now,
                                             description: "come play", status: "approved")
    pending  = @totem.bulletin_posts.create!(title: "Secret pending", starts_at: 2.days.from_now,
                                             description: "hidden", status: "pending")
    get bulletin_board_path(@totem.slug)
    assert_select "h2.bb-title", text: /Approved jam/
    assert_select "h2.bb-title", text: /Secret pending/, count: 0
  end

  test "empty state shows when no approved posts" do
    get bulletin_board_path(@totem.slug)
    assert_select ".bb-empty-title", text: /nothing posted here yet/i
  end

  # ── Create ─────────────────────────────────────────────────────────────────

  test "POST creates a pending post and captures IP" do
    assert_difference "BulletinPost.count", 1 do
      post bulletin_board_posts_path(@totem.slug), params: {
        bulletin_post: {
          title: "Porch concert",
          date: 5.days.from_now.strftime("%Y-%m-%d"),
          time: "19:00",
          description: "acoustic sets",
          recurring: "0"
        }
      }
    end
    created = BulletinPost.last
    assert_equal "pending", created.status
    assert_equal "Porch concert", created.title
    assert created.submitter_ip.present?
    assert_redirected_to bulletin_board_path(@totem.slug)
  end

  test "POST composes starts_at from date and time in Eastern time" do
    post bulletin_board_posts_path(@totem.slug), params: {
      bulletin_post: {
        title: "Timed event", date: "2030-11-15", time: "19:00",
        description: "x", recurring: "0"
      }
    }
    created = BulletinPost.last
    eastern = created.starts_at.in_time_zone("America/New_York")
    assert_equal "2030-11-15 19:00", eastern.strftime("%Y-%m-%d %H:%M")
  end

  test "POST with recurring keeps cadence" do
    post bulletin_board_posts_path(@totem.slug), params: {
      bulletin_post: {
        title: "Weekly run", date: 3.days.from_now.strftime("%Y-%m-%d"), time: "08:00",
        description: "5k", recurring: "1", recurrence_cadence: "weekly"
      }
    }
    assert_equal "weekly", BulletinPost.last.recurrence_cadence
  end

  test "POST drops cadence when not recurring" do
    post bulletin_board_posts_path(@totem.slug), params: {
      bulletin_post: {
        title: "One off", date: 3.days.from_now.strftime("%Y-%m-%d"), time: "08:00",
        description: "x", recurring: "0", recurrence_cadence: "weekly"
      }
    }
    assert_nil BulletinPost.last.recurrence_cadence
  end

  test "POST with invalid data does not create and re-renders" do
    assert_no_difference "BulletinPost.count" do
      post bulletin_board_posts_path(@totem.slug), params: {
        bulletin_post: { title: "", date: "", time: "", description: "", recurring: "0" }
      }
    end
    assert_response :unprocessable_entity
  end
end
