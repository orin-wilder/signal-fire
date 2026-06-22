module Admin::AnalyticsHelper
  # Formats a board-view → submission conversion rate (0.0–1.0) as a percentage,
  # or an em dash when there was no traffic to divide by (rate is nil).
  def format_conversion(rate)
    return "—" if rate.nil?

    "#{(rate * 100).round(1)}%"
  end

  # Renders a lightweight inline-SVG bar chart from a series of [date, count]
  # pairs. No JS / charting dependency — just scaled <rect>s.
  def analytics_bar_chart(series, height: 120)
    return content_tag(:p, "No activity yet.", class: "text-stone/60 text-sm") if series.blank?

    max = series.map(&:last).max
    max = 1 if max.zero?
    count = series.size
    gap = 2
    bar_w = [ (600.0 - gap * (count - 1)) / count, 1 ].max

    bars = series.each_with_index.map do |(date, value), i|
      bar_h = (value.to_f / max) * (height - 16)
      x = i * (bar_w + gap)
      y = height - bar_h
      title = "#{date.strftime('%b %-d')}: #{value}"
      content_tag(:rect, content_tag(:title, title),
        x: x.round(2), y: y.round(2), width: bar_w.round(2), height: bar_h.round(2),
        rx: 1, class: "fill-ember/80 hover:fill-ember transition")
    end.join.html_safe

    content_tag(:svg, bars,
      viewBox: "0 0 600 #{height}", class: "w-full", role: "img",
      "aria-label": "Daily activity", preserveAspectRatio: "none")
  end
end
