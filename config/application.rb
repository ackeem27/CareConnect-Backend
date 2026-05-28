require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

class CustomDebugMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if env['PATH_INFO'] == '/debug_logs' && Rack::Utils.parse_query(env['QUERY_STRING'])['token'] == 'careconnect_debug_123'
      begin
        report = []
        report << "=== Debug Diagnosis Report ==="
        report << "Time: #{Time.current}"
        report << "Environment: #{Rails.env}"
        
        # Check database URL
        db_url = ENV['DATABASE_URL']
        if db_url
          # Censor password
          censored_url = db_url.gsub(/:([^@\/:]+)@/, ':xxxx@')
          report << "DATABASE_URL: #{censored_url}"
          
          # Test PG connection directly
          require 'pg'
          begin
            conn = PG.connect(db_url)
            conn.exec("SELECT 1")
            conn.close
            report << "PG connection check: SUCCESS!"
          rescue => e
            report << "PG connection check: FAILED!"
            report << "Error class: #{e.class}"
            report << "Error message: #{e.message}"
            report << "Backtrace:\n#{e.backtrace.first(10).join("\n")}"
          end
        else
          report << "DATABASE_URL: NOT SET"
        end

        # Rails database config check
        begin
          ActiveRecord::Base.establish_connection
          ActiveRecord::Base.connection.execute("SELECT 1")
          report << "ActiveRecord connection check: SUCCESS!"
          begin
            report << "Tables: #{ActiveRecord::Base.connection.tables.join(', ')}"
            report << "User count: #{User.count}"
          rescue => err
            report << "ActiveRecord query check: FAILED!"
            report << "Query check error class: #{err.class}"
            report << "Query check error message: #{err.message}"
          end
        rescue => e
          report << "ActiveRecord connection check: FAILED!"
          report << "Error class: #{e.class}"
          report << "Error message: #{e.message}"
          report << "Backtrace:\n#{e.backtrace.first(10).join("\n")}"
        end
        
        # Check log file
        log_path = Rails.root.join("log", "#{Rails.env}.log")
        if File.exist?(log_path)
          report << "\n=== Last 100 lines of log ==="
          lines = File.readlines(log_path).last(100)
          report << lines.join
        else
          report << "Log file not found at: #{log_path}"
        end
        
        return [200, { 'Content-Type' => 'text/plain; charset=utf-8' }, [report.join("\n")]]
      rescue => e
        return [500, { 'Content-Type' => 'text/plain; charset=utf-8' }, ["Error in diagnostic middleware: #{e.message}\n#{e.backtrace.join("\n")}"]]
      end
    end

    @app.call(env)
  end
end

module BackendHospitalManagement
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
    config.middleware.insert_before 0, CustomDebugMiddleware
    config.middleware.use Rack::Attack
  end
end
