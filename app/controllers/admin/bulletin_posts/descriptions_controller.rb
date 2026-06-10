class Admin::BulletinPosts::DescriptionsController < Admin::ApplicationController
  # Admin-only AI assist for bulletin-post descriptions (one-liners, ≤160 chars).
  # Only summarize is wired in the UI — it guarantees the ≤160 cap while
  # cleaning up the copy. enhance is available via the shared concern but unused.
  include DescriptionAssistable
end
