module BulletinBoardsHelper
  BOARD_TZ = "America/New_York".freeze

  # Renders an event start as the Civic Beacon datetime string.
  #   board (dotted day):  SAT · NOV 15 · 7:00P
  #   admin (plain day):   SAT NOV 15 · 7:00P
  def bulletin_when(starts_at, dotted_day: true)
    return "" if starts_at.blank?

    t    = starts_at.in_time_zone(BOARD_TZ)
    day  = t.strftime("%a").upcase            # SAT
    date = t.strftime("%b %-d").upcase        # NOV 15
    time = t.strftime("%-I:%M%p").chop.upcase # 7:00P (drop trailing M)

    day_sep = dotted_day ? " · " : " "
    "#{day}#{day_sep}#{date} · #{time}"
  end

  def bulletin_recurrence_label(post)
    post.recurrence_cadence.to_s.upcase
  end
end
