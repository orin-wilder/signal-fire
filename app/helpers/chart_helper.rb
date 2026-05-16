module ChartHelper
  def bar_chart_svg(data, event_start_time:, peak_color: "#DA5520", bar_color: "#C9C5C0", height: 120)
    return "".html_safe if data.empty?

    max       = data.values.max.to_f
    bar_width = 28
    gap       = 8
    total_width = data.size * (bar_width + gap) - gap

    bars = data.map.with_index do |(offset_minutes, count), i|
      x      = i * (bar_width + gap)
      bh     = [(count / max * height).round, 1].max
      y      = height - bh
      color  = (count == max) ? peak_color : bar_color
      label  = (event_start_time + offset_minutes.minutes).strftime("%-I:%M")

      <<~SVG
        <rect x="#{x}" y="#{y}" width="#{bar_width}" height="#{bh}" fill="#{color}" rx="2"/>
        <text x="#{x + bar_width / 2}" y="#{height + 16}" text-anchor="middle"
              font-size="9" fill="#898581" font-family="JetBrains Mono, monospace">#{label}</text>
      SVG
    end

    svg = <<~SVG
      <svg viewBox="0 0 #{total_width} #{height + 24}" xmlns="http://www.w3.org/2000/svg"
           class="w-full overflow-visible" aria-hidden="true">
        #{bars.join}
      </svg>
    SVG

    svg.html_safe
  end
end
