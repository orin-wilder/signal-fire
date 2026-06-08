require "test_helper"

class BulletinPostTest < ActiveSupport::TestCase
  setup do
    @totem = totems(:main_totem)
  end

  def build_post(attrs = {})
    @totem.bulletin_posts.build({
      title: "Sunset yoga",
      starts_at: 3.days.from_now,
      description: "Bring a mat",
      status: "pending"
    }.merge(attrs))
  end

  # ── Validations ────────────────────────────────────────────────────────────

  test "valid with required fields" do
    assert build_post.valid?
  end

  test "requires title" do
    assert_not build_post(title: "").valid?
  end

  test "title max 80 chars" do
    assert_not build_post(title: "x" * 81).valid?
    assert build_post(title: "x" * 80).valid?
  end

  test "requires description" do
    assert_not build_post(description: "").valid?
  end

  test "description max 160 chars" do
    assert_not build_post(description: "x" * 161).valid?
    assert build_post(description: "x" * 160).valid?
  end

  test "requires starts_at" do
    assert_not build_post(starts_at: nil).valid?
  end

  test "starts_at must be in the future on create" do
    assert_not build_post(starts_at: 1.hour.ago).valid?
  end

  test "past starts_at allowed on update (e.g. event simply elapsed)" do
    post = build_post
    post.save!
    post.update_column(:starts_at, 1.day.ago)
    post.title = "Renamed"
    assert post.valid?
  end

  test "recurrence_cadence required and validated when recurring" do
    assert_not build_post(recurring: true, recurrence_cadence: nil).valid?
    assert_not build_post(recurring: true, recurrence_cadence: "daily").valid?
    assert build_post(recurring: true, recurrence_cadence: "weekly").valid?
    assert build_post(recurring: true, recurrence_cadence: "monthly").valid?
  end

  test "recurrence_cadence ignored when not recurring" do
    assert build_post(recurring: false, recurrence_cadence: nil).valid?
  end

  # ── Scopes ─────────────────────────────────────────────────────────────────

  test "approved and pending scopes" do
    approved = build_post; approved.status = "approved"; approved.save!
    pending  = build_post; pending.save!
    assert_includes BulletinPost.approved, approved
    assert_not_includes BulletinPost.approved, pending
    assert_includes BulletinPost.pending, pending
  end

  test "upcoming includes future approved, excludes pending and past" do
    future   = build_post(starts_at: 2.days.from_now); future.status = "approved"; future.save!
    pending  = build_post(starts_at: 2.days.from_now); pending.save!
    past      = build_post; past.status = "approved"; past.save!; past.update_column(:starts_at, 2.days.ago)

    assert_includes BulletinPost.upcoming, future
    assert_not_includes BulletinPost.upcoming, pending
    assert_not_includes BulletinPost.upcoming, past
  end

  test "recurring approved posts stay upcoming even when start has passed" do
    rec = build_post(recurring: true, recurrence_cadence: "weekly")
    rec.status = "approved"; rec.save!
    rec.update_column(:starts_at, 5.days.ago)

    assert_includes BulletinPost.upcoming, rec
    assert_not_includes BulletinPost.past, rec
  end

  test "past includes elapsed one-time approved, ordered most recent first" do
    older = build_post; older.status = "approved"; older.save!; older.update_column(:starts_at, 10.days.ago)
    newer = build_post; newer.status = "approved"; newer.save!; newer.update_column(:starts_at, 2.days.ago)

    result = BulletinPost.past.to_a
    assert_equal [newer, older], result & [newer, older]
  end
end
