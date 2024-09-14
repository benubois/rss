require 'etc'

workers 0
threads_count = ENV.fetch("MAX_THREADS", 4)
threads threads_count, threads_count

environment ENV.fetch("RACK_ENV", "development")

shared_directory = File.join(File.expand_path("..", ENV["PWD"]), "shared")
shared_directory = File.directory?(shared_directory) ? shared_directory : ENV["PWD"]

pidfile File.join(shared_directory, "tmp", "puma.pid")
bind    File.join("unix://", shared_directory, "tmp", "puma.sock")
