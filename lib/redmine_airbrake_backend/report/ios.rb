module RedmineAirbrakeBackend
  # Represents a report contained in a notice
  class Report
    class Ios
      def self.parse(data)
        error = {
          backtrace:   [],
          attachments: []
        }

        header_finished      = false
        next_line_is_message = false
        crashed_thread       = false
        indicent_identifier  = nil

        data.split("\n").each do |line|
          if line =~ /^(Application Specific Information|Last Exception Backtrace|Thread \d+( Crashed)?):$/
            header_finished = true
          end

          unless header_finished
            key, value = line.split(':', 2)

            next if key.blank? || value.blank?

            error[:type]    = value.strip if key.strip == 'Exception Type'
            error[:message] = value.strip if key.strip == 'Exception Codes'

            indicent_identifier = value.strip if key.strip == 'Incident Identifier'
          end

          if next_line_is_message
            next_line_is_message = false

            error[:message] = line

            if line =~ /^\*\*\* Terminating app due to uncaught exception '([^']+)', reason: '\*\*\* (.*)'$/
              error[:type]    = Regexp.last_match(1)
              error[:message] = Regexp.last_match(2)
            end
          end

          if line =~ /^Thread \d+:$/
            crashed_thread = false
          end

          if crashed_thread
            if line =~ /^(\d+)\s+([^\s]+)\s+(0x[0-9a-f]+)\s+(.+) \+ (\d+)$/
              error[:backtrace] << {
                file:   Regexp.last_match(2),
                method: Regexp.last_match(4),
                line:   Regexp.last_match(5),
              }
            end
          end

          if error[:backtrace].blank? && line =~ /^(Last Exception Backtrace|Thread \d+ Crashed):$/
            crashed_thread = true
          end

          if line =~ /^Application Specific Information:$/
            next_line_is_message = true
          end
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
