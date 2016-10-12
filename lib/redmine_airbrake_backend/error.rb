require 'digest/md5'
require 'redmine_airbrake_backend/backtrace_element'

module RedmineAirbrakeBackend
  # Error received by airbrake
  class Error
    attr_reader :id, :type, :message, :backtrace

    def initialize(options)
      # Type
      @type = options[:type]

      # Message
      @message = options[:message]

      # Backtrace
      @backtrace = Array(options[:backtrace]).map { |b| BacktraceElement.new(b) }

      # Error ID
      @id = generate_id
    end

    private

    def generate_id
      h = []
      h << RedmineAirbrakeBackend.filter_hex_values(@type)
      h << RedmineAirbrakeBackend.filter_hex_values(@message)
      h += @backtrace.map(&:checksum).compact

      Digest::MD5.hexdigest(h.compact.join("\n"))
    end
  end
end
