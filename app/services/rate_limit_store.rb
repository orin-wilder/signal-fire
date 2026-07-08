# Cache store for ActionController's rate_limit. Two reasons this exists
# instead of the default:
#
# 1. Lazy Rails.cache lookup — rate_limit's store: default is captured at
#    class-load time, which pins the test environment's null store and makes
#    the limits untestable via the Rails.stub(:cache, ...) pattern the
#    submission-throttle tests already use.
# 2. Fail-open — a cache-backend outage must degrade to "no rate limiting",
#    not lock everyone out of sign-in. Mirrors the submission throttles
#    (see Totems::EventSubmissionsController).
module RateLimitStore
  def self.increment(key, amount = 1, **options)
    Rails.cache.increment(key, amount, **options)
  rescue StandardError => e
    Rails.logger.warn("[rate_limit] store error (fail-open): #{e.class}: #{e.message}")
    nil
  end
end
