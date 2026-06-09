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

  test "board show page links to the boards directory" do
    get bulletin_board_path(@totem.slug)
    assert_select "a.bb-otherboards[href=?]", bulletin_boards_directory_path, text: /see other boards/i
  end

  # ── Directory (/stpeteboards) ────────────────────────────────────────────────

  test "GET directory lists boards with an upcoming approved post and links to each board" do
    @totem.bulletin_posts.create!(title: "Approved jam", starts_at: 2.days.from_now,
                                  description: "come play", status: "approved")
    get bulletin_boards_directory_path
    assert_response :success
    assert_select "h2.bb-title", text: /#{@totem.name}/
    assert_select "a.bb-board-link[href=?]", bulletin_board_path(@totem.slug)
  end

  test "GET directory keeps a board listed only once even with several upcoming posts" do
    @totem.bulletin_posts.create!(title: "Jam one", starts_at: 2.days.from_now,
                                  description: "x", status: "approved")
    @totem.bulletin_posts.create!(title: "Jam two", starts_at: 5.days.from_now,
                                  description: "x", status: "approved")
    get bulletin_boards_directory_path
    assert_select "a.bb-board-link[href=?]", bulletin_board_path(@totem.slug), count: 1
  end

  test "GET directory excludes boards whose posts are only pending or past" do
    @totem.bulletin_posts.create!(title: "Secret pending", starts_at: 2.days.from_now,
                                  description: "x", status: "pending")
    past = totems(:secondary_totem).bulletin_posts.new(title: "Old jam", starts_at: 2.days.ago,
                                                       description: "x", status: "approved", recurring: false)
    past.save!(validate: false) # starts_at_in_future only runs on :create
    get bulletin_boards_directory_path
    assert_response :success
    assert_select "a.bb-board-link", count: 0
    assert_select ".bb-empty-title", text: /no active boards/i
  end

  test "GET directory only includes boards in the city" do
    other = Totem.create!(name: "Tampa Totem", slug: "tampa-totem", location: "Tampa Park",
                          city_slug: "tampa", active: true)
    other.bulletin_posts.create!(title: "Tampa jam", starts_at: 2.days.from_now,
                                 description: "x", status: "approved")
    get bulletin_boards_directory_path
    assert_select "a.bb-board-link[href=?]", bulletin_board_path(other.slug), count: 0
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
