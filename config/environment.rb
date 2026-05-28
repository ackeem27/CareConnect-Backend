# Load the Rails application.
require_relative "application"

# Initialize the Rails application with crash logging.
begin
  Rails.application.initialize!
rescue Exception => e
  $stdout.puts "\n=== CRITICAL BOOT CRASH DETECTED ==="
  $stdout.puts "Exception: #{e.class} - #{e.message}"
  $stdout.puts e.backtrace.join("\n")
  $stdout.puts "====================================\n"
  raise e
end
