class IcsService
  def self.generate(event)
    totem = event.totem
    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Signal Fire//EN",
      "CALSCALE:GREGORIAN",
      "BEGIN:VEVENT",
      "UID:#{event.slug}@signalfire.live",
      "DTSTART:#{fmt(event.start_time)}",
      "DTEND:#{fmt(event.end_time)}",
      "SUMMARY:#{esc(event.title)}",
      "DESCRIPTION:#{esc(event.description.to_s.truncate(500))}",
      "LOCATION:#{esc(totem.location)}",
      "URL:https://signalfire.live/t/#{totem.slug}/e/#{event.slug}",
    ]
    lines << "RRULE:#{event.recurrence_rule}" if event.recurring?
    lines += ["END:VEVENT", "END:VCALENDAR"]
    lines.join("\r\n") + "\r\n"
  end

  private_class_method def self.fmt(dt)
    dt.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  private_class_method def self.esc(str)
    str.to_s
       .gsub("\\", "\\\\\\\\")
       .gsub(",",  "\\,")
       .gsub(";",  "\\;")
       .gsub("\n", "\\n")
  end
end
