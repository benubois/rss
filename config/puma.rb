workers 0

threads_count = ENV.fetch("MAX_THREADS", 4)
threads threads_count, threads_count

if ENV["PUMA_SOCKET"] && ENV["PUMA_PID"]
  bind ENV["PUMA_SOCKET"]
  pidfile ENV["PUMA_PID"]
else
  port ENV.fetch("PORT", 3000)
  plugin :tmp_restart
end
