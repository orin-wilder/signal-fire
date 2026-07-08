# Idempotent seed data for local development.
# Run with: bin/rails db:seed

# Every account below shares the well-known password "password" — this data
# must never (re)load in production. render.yaml no longer runs db:seed, and
# this guard is the backstop in case that ever changes.
if Rails.env.production? && ENV["ALLOW_PROD_SEED"].blank?
  puts "Skipping seeds: demo data is not production-safe (set ALLOW_PROD_SEED=1 to override deliberately)."
  return
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def seed_check_ins(event:, users:, offsets:)
  offsets.each_with_index do |offset, i|
    user = users[i % users.size]
    CheckIn.find_or_create_by!(user: user, event: event) do |ci|
      ci.checked_in_at = event.start_time + offset.minutes
    end
  end
end

def make_host(email:, name:, display_name:, blurb:, host_story: nil)
  user = User.find_or_create_by!(email: email) do |u|
    u.name = name
    u.is_host = true
    u.auth_method = "email"
    u.password_digest = BCrypt::Password.create("password")
  end
  HostProfile.find_or_create_by!(user: user) do |p|
    p.display_name = display_name
    p.blurb = blurb
    p.host_story = host_story
    p.timezone = "America/New_York"
    p.invite_status = "active"
    p.invite_accepted_at = 1.month.ago
    p.invited_at = 1.month.ago
  end
  user
end

# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------

# Legacy dev host (kept for backwards compat with existing test flows)
host = make_host(
  email: "host@example.com",
  name: "Alex Rivera",
  display_name: "Alex Rivera",
  blurb: "Running coach and community builder. I organize group runs in the city.",
  host_story: "Alex has been organizing group runs in St. Pete for years. He started because he wanted accountability — and found out everyone else did too. No pace requirements, no judgment, just showing up."
)

# Waterfront North hosts — match wireframe personas
maria = make_host(
  email: "maria@example.com",
  name: "Maria Santos",
  display_name: "Maria",
  blurb: "Has been running Sunday Mass — Ecstatic Dance for three years. Welcomes newcomers every week.",
  host_story: "Maria started Sunday Mass three years ago because she needed a place to move without anyone watching. Now a hundred people show up on a good morning. She checks in with every newcomer personally."
)

priya = make_host(
  email: "priya@example.com",
  name: "Priya Nair",
  display_name: "Priya",
  blurb: "Acro practitioner and teacher. Loves helping beginners find their first base or flyer.",
  host_story: "Priya learned acro in a park just like this one. She hosts the jam because she remembers how intimidating it felt to show up alone. She'll spot you the first time, and she'll remember your name the second."
)

lena = make_host(
  email: "lena@example.com",
  name: "Lena Park",
  display_name: "Lena",
  blurb: "Morning meditation facilitator. Twenty minutes of stillness before the day takes over.",
  host_story: "Lena meditates every morning regardless of who shows up. The circle is just an open invitation to join her. She teaches nothing and imposes nothing — just twenty minutes of quiet before the day gets loud."
)

coach_j = make_host(
  email: "coachj@example.com",
  name: "Jamie Chen",
  display_name: "Coach J",
  blurb: "Co-ed sand volleyball every Tuesday and Thursday. All skill levels rotate through.",
  host_story: "Coach J played competitive beach volleyball for fifteen years. Now he runs open games because the sport is better when more people are playing it. He rotates teams every set and keeps the energy loose."
)

devon = make_host(
  email: "devon@example.com",
  name: "Devon Brooks",
  display_name: "Devon",
  blurb: "Runs the Coffee Circle drop-in. Good coffee, good people, no agenda.",
  host_story: "Devon started Coffee Circle after moving to St. Pete and not knowing anyone. It was a selfish move — she just wanted somewhere to go on Saturday mornings. It turns out a lot of people needed the same thing."
)

# Admin
User.find_or_create_by!(email: "admin@example.com") do |u|
  u.name = "Admin User"
  u.is_admin = true
  u.auth_method = "email"
  u.password_digest = BCrypt::Password.create("password")
end

# Regular users for testing follow states
follower = User.find_or_create_by!(email: "follower@example.com") do |u|
  u.name = "Sam Follower"
  u.auth_method = "email"
  u.password_digest = BCrypt::Password.create("password")
end

User.find_or_create_by!(email: "nofollows@example.com") do |u|
  u.name = "Casey Nofollows"
  u.auth_method = "email"
  u.password_digest = BCrypt::Password.create("password")
end

# Attendees used for check-in / Insights seeds (first names surfaced on Insights page)
attendees = [
  [ "ana@example.com",    "Ana Torres"     ],
  [ "jordan@example.com", "Jordan Lee"     ],
  [ "morgan@example.com", "Morgan Kim"     ],
  [ "taylor@example.com", "Taylor Brooks"  ],
  [ "river@example.com",  "River Chen"     ],
  [ "quinn@example.com",  "Quinn Reyes"    ],
  [ "dana@example.com",   "Dana Okafor"    ],
  [ "lee@example.com",    "Lee Nakamura"   ],
].map do |email, name|
  User.find_or_create_by!(email: email) do |u|
    u.name            = name
    u.auth_method     = "email"
    u.password_digest = BCrypt::Password.create("password")
  end
end

# ---------------------------------------------------------------------------
# Totems
# ---------------------------------------------------------------------------

# 1. Waterfront North — active board with multiple hosts (mirrors wireframe 4.1.1 / 4.2.4)
waterfront = Totem.find_or_create_by!(slug: "waterfront-north") do |t|
  t.name = "St. Pete Waterfront North"
  t.active = true
  t.location = "St. Petersburg"
  t.character_description = "The open lawn where St. Pete shows up to move, breathe, and be in community."
  t.neighborhood = "Downtown Waterfront"
  t.city_slug = "stpete"
end

# 2. Williams Park — empty/inactive state (mirrors wireframe 4.1.5)
williams = Totem.find_or_create_by!(slug: "williams-park") do |t|
  t.name = "Williams Park Lawn"
  t.active = true
  t.location = "St. Petersburg"
  t.character_description = "The shaded lawn where the city exhales. Morning gatherings, afternoon hangs, and everything in between."
  t.neighborhood = "Old Northeast"
  t.city_slug = "stpete"
end

# 3. North Shore Courts — active, single host (mirrors home screen card)
north_shore = Totem.find_or_create_by!(slug: "north-shore-courts") do |t|
  t.name = "North Shore Courts"
  t.active = true
  t.location = "St. Petersburg"
  t.character_description = "Sand courts on the bay. The regulars know each other by name and welcome anyone who shows up."
  t.neighborhood = "North Shore"
  t.city_slug = "stpete"
end

# 4. Legacy / dev totems (kept for existing test flows)
main_totem = Totem.find_or_create_by!(slug: "riverside-runners") do |t|
  t.name = "Riverside Runners"
  t.active = true
  t.location = "Riverside Park, NYC"
  t.sublocation = "Meet at the 79th St fountain"
  t.character_description = "A long-running crew that shows up rain or shine. All paces, all welcome."
  t.neighborhood = "Upper West Side"
  t.city_slug = "stpete"
end

Totem.find_or_create_by!(slug: "brooklyn-hikers") do |t|
  t.name = "Brooklyn Hikers"
  t.active = true
  t.location = "Prospect Park, Brooklyn"
  t.city_slug = "stpete"
end

Totem.find_or_create_by!(slug: "old-group") do |t|
  t.name = "Old Group"
  t.active = false
  t.location = "Somewhere"
  t.city_slug = "stpete"
end

# ---------------------------------------------------------------------------
# Host–Totem assignments
# ---------------------------------------------------------------------------

{
  waterfront => [maria, priya, lena, coach_j, devon],
  north_shore => [coach_j],
  main_totem  => [host],
}.each do |totem, hosts|
  hosts.each do |h|
    HostTotemAssignment.find_or_create_by!(host_user: h, totem: totem) do |a|
      a.assigned_at = 1.month.ago
    end
  end
end

# ---------------------------------------------------------------------------
# Totem follows
# ---------------------------------------------------------------------------

[waterfront, north_shore].each do |totem|
  TotemFavorite.find_or_create_by!(user: follower, totem: totem)
end

# ---------------------------------------------------------------------------
# Events — Waterfront North
# ---------------------------------------------------------------------------
# Weekly recurring events (normal / upcoming board state)
Event.find_or_create_by!(slug: "waterfront-north-sunday-mass-ecstatic-dance") do |e|
  e.approval_state = :published
  e.totem         = waterfront
  e.host_user     = maria
  e.title         = "Sunday Mass — Ecstatic Dance"
  e.recurrence_rule = "FREQ=WEEKLY;BYDAY=SU"
  e.start_time    = Time.current.next_occurring(:sunday).change(hour: 9, min: 0)
  e.end_time      = Time.current.next_occurring(:sunday).change(hour: 10, min: 30)
  e.chat_url      = "https://chat.whatsapp.com/ecstaticdancestpete"
  e.chat_platform = :whatsapp
  e.status        = :active
  e.description   = "Come as you are. We dance for ninety minutes with no talking on the floor. The first set is silent, the second is musical. Bring water. Leave your shoes at the door."
  e.community_norms = "No phones on the floor\nRespect the silent opening\nLeave judgment at the door"
end

Event.find_or_create_by!(slug: "waterfront-north-acroyoga-jam") do |e|
  e.approval_state = :published
  e.totem         = waterfront
  e.host_user     = priya
  e.title         = "AcroYoga Jam"
  e.recurrence_rule = "FREQ=WEEKLY;BYDAY=SA"
  e.start_time    = Time.current.next_occurring(:saturday).change(hour: 16, min: 0)
  e.end_time      = Time.current.next_occurring(:saturday).change(hour: 17, min: 30)
  e.chat_url      = "https://discord.gg/acroyogastpete"
  e.chat_platform = :discord
  e.status        = :active
  e.description   = "Partner acrobatics in a mellow circle. Drop in or pair up."
  e.community_norms = "Ask before touching\nCommunicate your comfort level\nSpotters encouraged"
end

Event.find_or_create_by!(slug: "waterfront-north-meditation-circle") do |e|
  e.approval_state = :published
  e.totem         = waterfront
  e.host_user     = lena
  e.title         = "Meditation Circle"
  e.recurrence_rule = "FREQ=WEEKLY;BYDAY=MO"
  e.start_time    = Time.current.next_occurring(:monday).change(hour: 7, min: 0)
  e.end_time      = Time.current.next_occurring(:monday).change(hour: 7, min: 30)
  e.chat_url      = "https://t.me/meditationstpete"
  e.chat_platform = :telegram
  e.status        = :active
  e.description   = "Twenty minutes of silent sit. Mats provided."
  e.community_norms = "Arrive on time\nSilence your phone\nMats are shared — please clean after use"
end

Event.find_or_create_by!(slug: "waterfront-north-sand-volleyball") do |e|
  e.approval_state = :published
  e.totem         = waterfront
  e.host_user     = coach_j
  e.title         = "Sand Volleyball"
  e.recurrence_rule = "FREQ=WEEKLY;BYDAY=TU"
  e.start_time    = Time.current.next_occurring(:tuesday).change(hour: 18, min: 0)
  e.end_time      = Time.current.next_occurring(:tuesday).change(hour: 20, min: 0)
  e.chat_url      = "https://signal.group/sandvolleystpete"
  e.chat_platform = :signal
  e.status        = :active
  e.description   = "Co-ed open play. All skill levels — we rotate teams each set."
end

# One-time upcoming event (tests one-time card rendering)
Event.find_or_create_by!(slug: "waterfront-north-coffee-circle") do |e|
  e.approval_state = :published
  e.totem         = waterfront
  e.host_user     = devon
  e.title         = "Coffee Circle"
  e.recurrence_rule = nil
  e.start_time    = 3.days.from_now.change(hour: 10, min: 0)
  e.end_time      = 3.days.from_now.change(hour: 11, min: 0)
  e.chat_url      = "https://groupme.com/join_group/coffeecirclestpete"
  e.chat_platform = :groupme
  e.status        = :active
  e.description   = "Casual drop-in coffee hang. Good coffee, good people, no agenda."
end

# Happening-now event (tests active-now card + check-in flow)
happening_now = Event.find_or_create_by!(slug: "waterfront-north-ecstatic-dance-now") do |e|
  e.approval_state = :published
  e.totem         = waterfront
  e.host_user     = maria
  e.title         = "Ecstatic Dance"
  e.recurrence_rule = nil
  e.start_time    = 20.minutes.ago
  e.end_time      = 70.minutes.from_now
  e.chat_url      = "https://your-workspace.slack.com/join/ecstaticdancenow"
  e.chat_platform = :slack
  e.status        = :active
  e.description   = "Move your body freely. Silent first set."
  e.community_norms = "No phones on the floor\nSilent first set\nLeave judgment at the door"
end

# Starting-soon event (tests starting-soon card state)
Event.find_or_create_by!(slug: "waterfront-north-coffee-circle-soon") do |e|
  e.approval_state = :published
  e.totem         = waterfront
  e.host_user     = devon
  e.title         = "Coffee Circle"
  e.recurrence_rule = nil
  e.start_time    = 20.minutes.from_now
  e.end_time      = 80.minutes.from_now
  e.chat_url      = "https://groupme.com/join_group/coffeecirclesoon"
  e.chat_platform = :groupme
  e.status        = :active
  e.description   = "Quick drop-in coffee hang before the morning gets going."
end

# Just-ended event (tests just-ended card + grace-window check-in)
Event.find_or_create_by!(slug: "waterfront-north-sunrise-meditation") do |e|
  e.approval_state = :published
  e.totem         = waterfront
  e.host_user     = lena
  e.title         = "Sunrise Meditation"
  e.recurrence_rule = nil
  e.start_time    = 50.minutes.ago
  e.end_time      = 10.minutes.ago
  e.chat_url      = "https://t.me/sunrisemeditation"
  e.chat_platform = :telegram
  e.status        = :active
  e.description   = "Seven AM silent sit on the waterfront."
  e.community_norms = "Arrive quietly\nSilence your phone"
end

# Cancelled event (tests cancelled banner + chat button behaviour)
Event.find_or_create_by!(slug: "waterfront-north-volleyball-tournament") do |e|
  e.approval_state = :published
  e.totem         = waterfront
  e.host_user     = coach_j
  e.title         = "Volleyball Tournament"
  e.recurrence_rule = nil
  e.start_time    = 2.days.from_now.change(hour: 14, min: 0)
  e.end_time      = 2.days.from_now.change(hour: 18, min: 0)
  e.chat_url      = "https://signal.group/volleytournament"
  e.chat_platform = :signal
  e.status        = :cancelled
  e.description   = "Friendly open bracket. All skill levels."
end

AnonymousCheckInCount.find_or_create_by!(event: happening_now) { |c| c.count = 7 }

# ---------------------------------------------------------------------------
# Events — North Shore Courts
# ---------------------------------------------------------------------------

north_shore_pickup = Event.find_or_create_by!(slug: "north-shore-courts-thursday-pickup") do |e|
  e.approval_state = :published
  e.totem         = north_shore
  e.host_user     = coach_j
  e.title         = "Thursday Pickup"
  e.recurrence_rule = "FREQ=WEEKLY;BYDAY=TH"
  e.start_time    = Time.current.next_occurring(:thursday).change(hour: 18, min: 0)
  e.end_time      = Time.current.next_occurring(:thursday).change(hour: 20, min: 0)
  e.chat_url      = "https://discord.gg/northshorepickup"
  e.chat_platform = :discord
  e.status        = :active
  e.description   = "Open pickup volleyball at North Shore. Show up, we'll sort teams."
end

# ---------------------------------------------------------------------------
# Events — Legacy Riverside Runners (unchanged)
# ---------------------------------------------------------------------------

Event.find_or_create_by!(slug: "riverside-runners-saturday-long-run") do |e|
  e.approval_state = :published
  e.totem         = main_totem
  e.host_user     = host
  e.title         = "Saturday Long Run"
  e.recurrence_rule = "FREQ=WEEKLY;BYDAY=SA"
  e.start_time    = Time.current.next_occurring(:saturday).change(hour: 7, min: 0)
  e.end_time      = Time.current.next_occurring(:saturday).change(hour: 9, min: 0)
  e.chat_url      = "https://your-workspace.slack.com/join/riversidesaturdayrun"
  e.chat_platform = :slack
  e.status        = :active
  e.description   = "Our classic weekly long run. All paces welcome. We regroup at every mile marker."
  e.community_norms = "Be kind. Regroup. No one gets left behind."
end

Event.find_or_create_by!(slug: "riverside-runners-thursday-track-workout") do |e|
  e.approval_state = :published
  e.totem         = main_totem
  e.host_user     = host
  e.title         = "Thursday Track Workout"
  e.recurrence_rule = "FREQ=WEEKLY;BYDAY=TH"
  e.start_time    = Time.current.next_occurring(:thursday).change(hour: 6, min: 30)
  e.end_time      = Time.current.next_occurring(:thursday).change(hour: 7, min: 30)
  e.chat_url      = "https://chat.whatsapp.com/riversidetrack"
  e.chat_platform = :whatsapp
  e.status        = :active
  e.description   = "Speed work on the track. Expect intervals, tempo miles, and suffering together."
end

active_event = Event.find_or_create_by!(slug: "riverside-runners-morning-shakeout") do |e|
  e.approval_state = :published
  e.totem         = main_totem
  e.host_user     = host
  e.title         = "Morning Shakeout"
  e.recurrence_rule = nil
  e.start_time    = 20.minutes.ago
  e.end_time      = 40.minutes.from_now
  e.chat_url      = "https://discord.gg/riversideshakeout"
  e.chat_platform = :discord
  e.status        = :active
  e.description   = "Easy 3-mile shakeout. Perfect for shaking off the week."
end

Event.find_or_create_by!(slug: "riverside-runners-cancelled-run") do |e|
  e.approval_state = :published
  e.totem         = main_totem
  e.host_user     = host
  e.title         = "Cancelled Run"
  e.recurrence_rule = nil
  e.start_time    = 2.days.from_now.change(hour: 7)
  e.end_time      = 2.days.from_now.change(hour: 9)
  e.chat_url      = "https://t.me/riversidecancelled"
  e.chat_platform = :telegram
  e.status        = :cancelled
  e.description   = "This run was cancelled due to weather."
end

AnonymousCheckInCount.find_or_create_by!(event: active_event) { |c| c.count = 12 }

# ---------------------------------------------------------------------------
# Past Events + Check-ins (for Insights page development)
#
# Three events with realistic check-in spreads across 15-min windows.
# Two events intentionally left empty to test the zero-state.
# ---------------------------------------------------------------------------

# ── 1. Sunday Mass — big turnout, good chart shape ──────────────────────────
sunday_mass_past = Event.find_or_create_by!(slug: "waterfront-north-sunday-mass-past") do |e|
  e.approval_state = :published
  e.totem           = waterfront
  e.host_user       = maria
  e.title           = "Sunday Mass — Ecstatic Dance"
  e.recurrence_rule = nil
  e.start_time      = 2.weeks.ago.change(hour: 9, min: 0)
  e.end_time        = 2.weeks.ago.change(hour: 10, min: 30)
  e.chat_url        = "https://chat.whatsapp.com/ecstaticdancestpete"
  e.chat_platform   = :whatsapp
  e.status          = :active
  e.description     = "Come as you are. We dance for ninety minutes with no talking on the floor."
end

# Offsets (minutes from event.start_time): spread across 4 windows, peak at 0–15
seed_check_ins(
  event:   sunday_mass_past,
  users:   attendees,
  offsets: [ -24, -11, -4, 6, 10, 18, 31, 44 ]
)

AnonymousCheckInCount.find_or_create_by!(event: sunday_mass_past) { |c| c.count = 9 }

# First 3 attendees are first-timers to Maria's events
attendees.first(3).each do |user|
  ci = CheckIn.find_by(user: user, event: sunday_mass_past)
  next unless ci
  UserHostFirstSeen.find_or_create_by!(user: user, host_user: maria) do |r|
    r.first_seen_at = ci.checked_in_at
  end
end

# ── 2. AcroYoga Jam — medium turnout ────────────────────────────────────────
acroyoga_past = Event.find_or_create_by!(slug: "waterfront-north-acroyoga-past") do |e|
  e.approval_state = :published
  e.totem           = waterfront
  e.host_user       = priya
  e.title           = "AcroYoga Jam"
  e.recurrence_rule = nil
  e.start_time      = 11.days.ago.change(hour: 16, min: 0)
  e.end_time        = 11.days.ago.change(hour: 17, min: 30)
  e.chat_url        = "https://discord.gg/acroyogastpete"
  e.chat_platform   = :discord
  e.status          = :active
  e.description     = "Partner acrobatics in a mellow circle. Drop in or pair up."
end

seed_check_ins(
  event:   acroyoga_past,
  users:   attendees.first(5),
  offsets: [ -9, 4, 11, 23, 38 ]
)

AnonymousCheckInCount.find_or_create_by!(event: acroyoga_past) { |c| c.count = 4 }

attendees.first(2).each do |user|
  ci = CheckIn.find_by(user: user, event: acroyoga_past)
  next unless ci
  UserHostFirstSeen.find_or_create_by!(user: user, host_user: priya) do |r|
    r.first_seen_at = ci.checked_in_at
  end
end

# ── 3. Thursday Track (Riverside) — small turnout ───────────────────────────
track_past = Event.find_or_create_by!(slug: "riverside-runners-thursday-track-past") do |e|
  e.approval_state = :published
  e.totem           = main_totem
  e.host_user       = host
  e.title           = "Thursday Track Workout"
  e.recurrence_rule = nil
  e.start_time      = 1.week.ago.change(hour: 6, min: 30)
  e.end_time        = 1.week.ago.change(hour: 7, min: 30)
  e.chat_url        = "https://chat.whatsapp.com/riversidetrack"
  e.chat_platform   = :whatsapp
  e.status          = :active
  e.description     = "Speed work on the track. Intervals, tempo miles, suffering together."
end

seed_check_ins(
  event:   track_past,
  users:   attendees.first(6),
  offsets: [ -17, -6, 2, 9, 21, 35 ]
)

AnonymousCheckInCount.find_or_create_by!(event: track_past) { |c| c.count = 3 }

attendees.first(4).each do |user|
  ci = CheckIn.find_by(user: user, event: track_past)
  next unless ci
  UserHostFirstSeen.find_or_create_by!(user: user, host_user: host) do |r|
    r.first_seen_at = ci.checked_in_at
  end
end

# ── 4. Meditation Circle — no check-ins (zero state) ────────────────────────
Event.find_or_create_by!(slug: "waterfront-north-meditation-past") do |e|
  e.approval_state = :published
  e.totem           = waterfront
  e.host_user       = lena
  e.title           = "Meditation Circle"
  e.recurrence_rule = nil
  e.start_time      = 9.days.ago.change(hour: 7, min: 0)
  e.end_time        = 9.days.ago.change(hour: 7, min: 30)
  e.chat_url        = "https://t.me/meditationstpete"
  e.chat_platform   = :telegram
  e.status          = :active
  e.description     = "Twenty minutes of silent sit."
end

# ── 5. North Shore Thursday Pickup — no check-ins (zero state) ──────────────
Event.find_or_create_by!(slug: "north-shore-courts-pickup-past") do |e|
  e.approval_state = :published
  e.totem           = north_shore
  e.host_user       = coach_j
  e.title           = "Thursday Pickup"
  e.recurrence_rule = nil
  e.start_time      = 8.days.ago.change(hour: 18, min: 0)
  e.end_time        = 8.days.ago.change(hour: 20, min: 0)
  e.chat_url        = "https://discord.gg/northshorepickup"
  e.chat_platform   = :discord
  e.status          = :active
  e.description     = "Open pickup volleyball at North Shore."
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

puts "Seeded:"
puts "  Users:  #{User.count} (password: 'password' for all)"
puts "  Totems: #{Totem.count} (#{Totem.pluck(:slug).join(', ')})"
puts "  Events: #{Event.count}"
puts "  CheckIns: #{CheckIn.count} auth, #{AnonymousCheckInCount.sum(:count)} anon"
puts ""
puts "── Wireframe boards ──────────────────────────────────────────"
puts "  Active (4 hosts, all window states):"
puts "    http://localhost:3000/t/waterfront-north"
puts "  Happening-now event detail:"
puts "    http://localhost:3000/t/waterfront-north/e/waterfront-north-ecstatic-dance-now"
puts "  Starting-soon event detail:"
puts "    http://localhost:3000/t/waterfront-north/e/waterfront-north-coffee-circle-soon"
puts "  Just-ended event detail:"
puts "    http://localhost:3000/t/waterfront-north/e/waterfront-north-sunrise-meditation"
puts "  Cancelled event detail:"
puts "    http://localhost:3000/t/waterfront-north/e/waterfront-north-volleyball-tournament"
puts "  Empty landing (4.1.5):"
puts "    http://localhost:3000/t/williams-park"
puts ""
puts "── Insights (host login: maria@example.com / password) ───────"
puts "  Big turnout (8 auth + 9 anon, 3 first-timers):"
puts "    http://localhost:3000/host/insights/waterfront-north-sunday-mass-past"
puts "  Medium turnout (5 auth + 4 anon, 2 first-timers):"
puts "    http://localhost:3000/host/insights/waterfront-north-acroyoga-past"
puts "  Small turnout — host login: host@example.com"
puts "    http://localhost:3000/host/insights/riverside-runners-thursday-track-past"
puts "  Zero check-ins (quiet state):"
puts "    http://localhost:3000/host/insights/waterfront-north-meditation-past"
puts "    http://localhost:3000/host/insights/north-shore-courts-pickup-past"
puts ""
puts "── Legacy dev boards ─────────────────────────────────────────"
puts "  Active:  http://localhost:3000/t/riverside-runners"
puts "  Empty:   http://localhost:3000/t/brooklyn-hikers"
puts "  Inactive: http://localhost:3000/t/old-group"
