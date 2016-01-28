require 'redmine_airbrake_backend/notice'


module RedmineAirbrakeBackend
  # iOS Report received by airbrake
  class IosReport < Notice
    def initialize(options)
      error, application, attachments = self.class.parse(options[:report])

      super({
          errors:      [Error.new(error)],
          context:     options[:context],
          application: application,
          attachments: attachments
        })
    end

    private

    def self.parse(data)
      error       = { backtrace: [] }
      application = {}
      attachments = []

      header_finished      = false
      next_line_is_message = false
      crashed_thread       = false
      indicent_identifier  = nil

      data.split("\n").each do |line|
        header_finished = true if line =~ /^(Application Specific Information|Last Exception Backtrace|Thread \d+( Crashed)?):$/

        unless header_finished
          ii = parse_header_line(line, error, application)
          indicent_identifier ||= ii if ii
        end

        if next_line_is_message
          next_line_is_message = false

          parse_message(line, error)
        end

        crashed_thread = false if line =~ /^Thread \d+:$/

        if crashed_thread
          backtrace = parse_backtrace_element(line)
          error[:backtrace] << backtrace if backtrace
        end

        crashed_thread = true if error[:backtrace].compact.blank? && line =~ /^(Last Exception Backtrace|Thread \d+ Crashed):$/

        next_line_is_message = true if line =~ /^Application Specific Information:$/
      end

      return nil if error.blank?

      attachments << {
        filename: "#{indicent_identifier}.crash",
        data:     data
      } if indicent_identifier.present?

      [error, application, attachments]
    end

    def self.parse_header_line(line, error, application)
      key, value = line.split(':', 2).map { |s| s.strip }

      return nil if key.blank? || value.blank?

      case key
      when 'Exception Type'
        error[:type] = value
      when 'Exception Codes'
        error[:message] = value
      when 'Incident Identifier'
        return value
      when 'Identifier'
        application[:name] = value
      when 'Version'
        application[:version] = value
      end

      nil
    end

    def self.parse_message(line, error)
      error[:message] = line

      if line =~ /^\*\*\* Terminating app due to uncaught exception '([^']+)', reason: '\*\*\* (.*)'$/
        error[:type]    = Regexp.last_match(1)
        error[:message] = Regexp.last_match(2)
      else
        error[:message] = line
      end
    end

    def self.parse_backtrace_element(line)
      if line =~ /^(\d+)\s+([^\s]+)\s+(0x[0-9a-f]+)\s+(.+) \+ (\d+)$/
        {
          file:     Regexp.last_match(2),
          function: Regexp.last_match(4),
          line:     Regexp.last_match(5)
        }
      else
        nil
      end
    end
  end
end
