require "test_helper"

class BulletinPostEnhancementsTest < ActiveSupport::TestCase
  def build_post(**attrs)
    totems(:main_totem).bulletin_posts.new({
      title: "Jam", description: "come play", starts_at: 2.days.from_now, status: "pending"
    }.merge(attrs))
  end

  test "source_url accepts http(s) and blank, rejects other schemes" do
    assert build_post(source_url: "https://example.com").valid?
    assert build_post(source_url: nil).valid?

    bad = build_post(source_url: "javascript:alert(1)")
    assert_not bad.valid?
    assert_includes bad.errors[:source_url].join, "http"
  end

  test "source defaults to public_submission" do
    post = totems(:main_totem).bulletin_posts.create!(
      title: "Walk", description: "morning loop", starts_at: 2.days.from_now, status: "pending"
    )
    assert_equal "public_submission", post.source
  end

  test "source_label humanizes the provenance" do
    assert_equal "Visitor", build_post(source: "public_submission").source_label
    assert_equal "Scouted", build_post(source: "scouted").source_label
  end
end
