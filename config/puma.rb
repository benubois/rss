workers 0

threads_count = ENV.fetch("MAX_THREADS", 4)
threads threads_count, threads_count

if ENV.fetch("RAILS_ENV") == "production"
  pidfile File.join(ENV["SHARED_DIRECTORY"], "tmp", "puma.pid")
  bind File.join("unix://", ENV["SHARED_DIRECTORY"], "tmp", "puma.sock")
else
  port ENV.fetch("PORT", 3000)
  plugin :tmp_restart
end
