require "test_helper"

# Phase 6 — short_code generation + validation on Totem.
class TotemShortCodeTest < ActiveSupport::TestCase
  def build_totem(**attrs)
    Totem.new({ name: "New Spot", location: "Park", city_slug: "stpete" }.merge(attrs))
  end

  test "generates a 2-digit short_code on create" do
    totem = build_totem
    assert totem.save, totem.errors.full_messages.to_sentence
    assert_match(/\A\d{2}\z/, totem.short_code)
  end

  test "generated codes are unique and avoid existing ones" do
    taken = Totem.pluck(:short_code).compact
    codes = Array.new(6) { |i| build_totem(name: "Spot #{i}").tap(&:save!).short_code }
    assert_equal codes, codes.uniq, "generated codes collided"
    assert_empty codes & taken, "regenerated an already-used code"
  end

  test "an explicit short_code is kept, not regenerated" do
    totem = build_totem(short_code: "77")
    assert totem.save
    assert_equal "77", totem.short_code
  end

  test "rejects a duplicate short_code" do
    dup = build_totem(short_code: totems(:main_totem).short_code)
    assert_not dup.valid?
    assert dup.errors[:short_code].any?
  end

  test "rejects a non-numeric or too-short code" do
    assert_not build_totem(short_code: "ab").valid?
    assert_not build_totem(short_code: "5").valid?
  end
end
