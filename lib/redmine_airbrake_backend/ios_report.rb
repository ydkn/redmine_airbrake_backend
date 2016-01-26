require 'redmine_airbrake_backend/error'


module RedmineAirbrakeBackend
  # iOS Report received by airbrake
  class IosReport < Error
    def initialize(data)
      super(IosReport.parse(data))
    end

    private

    def self.parse(data)
      error = {
        application: {},
        backtrace:   [],
        attachments: [],
      }

      header_finished      = false
      next_line_is_message = false
      crashed_thread       = false
      indicent_identifier  = nil

      data.split("\n").each do |line|
        header_finished = true if line =~ /^(Application Specific Information|Last Exception Backtrace|Thread \d+( Crashed)?):$/

        unless header_finishedii
          ii = parse_header_line(line, error)
          indicent_identifier ||= ii if ii
        end

        if next_line_is_message
          next_line_is_message = false

          parse_message(line, error)
        end

        crashed_thread = false if line =~ /^Thread \d+:$/

        error[:backtrace] << parse_backtrace_element(line) if crashed_thread

        crashed_thread = true if error[:backtrace].compact.blank? && line =~ /^(Last Exception Backtrace|Thread \d+ Crashed):$/

        next_line_is_message = true if line =~ /^Application Specific Information:$/
      end

      return nil if error.blank?

      error[:attachments] << {
        filename: "#{indicent_identifier}.crash",
        data:     data
      } if indicent_identifier.present?

      error
    end

    def self.parse_header_line(line, error)
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
        error[:application][:name] = value
      when 'Version'
        error[:application][:version] = value
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
