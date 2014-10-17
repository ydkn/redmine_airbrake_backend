module RedmineAirbrakeBackend
  # Represents a report contained in a request
  class Report
    # iOS report
    class Ios
      # Parse an iOS crash log
      def self.parse(data)
        error = {
          backtrace:   [],
          attachments: [],
          application: {}
        }

        header_finished      = false
        next_line_is_message = false
        crashed_thread       = false
        indicent_identifier  = nil

        data.split("\n").each do |line|
          header_finished = true if line =~ /^(Application Specific Information|Last Exception Backtrace|Thread \d+( Crashed)?):$/

          unless header_finished
            key, value = line.split(':', 2).map { |s| s.strip }

            next if key.blank? || value.blank?

            case key
            when 'Exception Type'
              error[:type] = value
            when 'Exception Codes'
              error[:message] = value
            when 'Incident Identifier'
              indicent_identifier = value
            when 'Identifier'
              error[:application][:name] = value
            when 'Version'
              error[:application][:version] = value
            end
          end

          if next_line_is_message
            next_line_is_message = false

            error[:message] = line

            if line =~ /^\*\*\* Terminating app due to uncaught exception '([^']+)', reason: '\*\*\* (.*)'$/
              error[:type]    = Regexp.last_match(1)
              error[:message] = Regexp.last_match(2)
            else
              error[:message] = line
            end
          end

          crashed_thread = false if line =~ /^Thread \d+:$/

          if crashed_thread
            if line =~ /^(\d+)\s+([^\s]+)\s+(0x[0-9a-f]+)\s+(.+) \+ (\d+)$/
              error[:backtrace] << {
                file:   Regexp.last_match(2),
                method: Regexp.last_match(4),
                line:   Regexp.last_match(5),
              }
            end
          end

          crashed_thread = true if error[:backtrace].blank? && line =~ /^(Last Exception Backtrace|Thread \d+ Crashed):$/

          next_line_is_message = true if line =~ /^Application Specific Information:$/
        end

        return nil if error.blank?

        error[:attachments] << {
          filename: "#{indicent_identifier}.crash",
          data:     data
        } if indicent_identifier.present?

        error
      end
    end
  end
end
