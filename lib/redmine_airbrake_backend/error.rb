require 'digest/md5'
require 'redmine_airbrake_backend/backtrace_element'


module RedmineAirbrakeBackend
  # Error received by airbrake
  class Error
    attr_reader :type, :message, :backtrace
    attr_reader :id, :subject, :application, :attachments

    def initialize(data)
      # Type
      @type = data[:type]

      # Message
      @message = data[:message]

      # Backtrace
      @backtrace = data[:backtrace].map { |b| BacktraceElement.new(b) }

      # Error ID
      @id = generate_id

      # Subject
      @subject = generate_subject

      # Attachments
      @attachments = (data[:attachments].presence || []).compact

      # Application
      @application = data[:application].presence
    end

    private

    def generate_id
      h = []
      h << RedmineAirbrakeBackend.filter_hex_values(@type)
      h << RedmineAirbrakeBackend.filter_hex_values(@message)
      h += @backtrace.map(&:checksum).compact

      Digest::MD5.hexdigest(h.compact.join("\n"))
    end

    def generate_subject
      s = ''

      if @type.blank? || @message.starts_with?("#{@type}:")
        s = "[#{@id[0..7]}] #{@message}"
      else
        s = "[#{@id[0..7]}] #{@type}: #{@message}"
      end

      s[0..254].strip
    end
  end
end
