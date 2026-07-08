class ApplicationJob < ActiveJob::Base
  # Transient failures (Expo push, Resend, OpenRouter, Postgres contention)
  # should retry with backoff instead of landing silently in
  # solid_queue_failed_executions, which nobody watches.
  # Net::OpenTimeout/ReadTimeout are Timeout::Error subclasses.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3
  retry_on Timeout::Error, SocketError, OpenSSL::SSL::SSLError,
           Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EPIPE,
           wait: :polynomially_longer, attempts: 5

  # Safe to drop when the underlying record is gone by the time the job runs
  discard_on ActiveJob::DeserializationError
end
