require 'redmine_airbrake_backend/request'

module RedmineAirbrakeBackend
  class Request
    # Represents a JSON request received by airbrake
    class JSON < ::RedmineAirbrakeBackend::Request
      # Creates a request from a parsed json request
      def self.parse(parsed_json_data)
        raise Invalid if parsed_json_data.blank?

        context  = parse_plain_section(parsed_json_data[:context])
        params   = parse_plain_section(parsed_json_data[:params])
        notifier = parse_plain_section(parsed_json_data[:notifier])
        request  = parse_plain_section(parsed_json_data[:request])
        env      = parse_plain_section(parsed_json_data[:environment])
        config   = parsed_json_data[:key]

        errors  = []
        errors += parse_errors(parsed_json_data[:errors])
        errors += parse_report(parsed_json_data[:type], parsed_json_data[:report])
        errors.compact!

        raise Invalid.new('No error or report found') if errors.blank?

        new(config, context: context, params: params, notifier: notifier, errors: errors, request: request, env: env)
      end

      private

      def self.parse_plain_section(section_data)
        return {} if section_data.blank?

        section_data.symbolize_keys
      end

      def self.parse_errors(errors)
        errors = []

        (errors || []).each do |error_data|
          error = parse_error(error_data)
          errors << ::RedmineAirbrakeBackend::Error.new(error) if error.present?
        end

        errors
      end

      def self.parse_error(error_data)
        return nil if error_data.blank?

        error             = {}
        error[:type]      = secure_type(error_data[:type])
        error[:message]   = error_data[:message]
        error[:backtrace] = error_data[:backtrace].map do |backtrace_element|
          {
            line:   backtrace_element[:line].to_i,
            file:   backtrace_element[:file],
            method: (backtrace_element[:method] || backtrace_element[:function])
          }
        end

        error
      end

      def self.parse_report(type, report_data)
        return nil if report_data.blank?

        sec_type = secure_type(type)

        require "redmine_airbrake_backend/report/#{sec_type}" rescue nil

        clazz = "RedmineAirbrakeBackend::Report::#{sec_type.camelize}".constantize rescue nil

        return nil if clazz.blank?

        report = clazz.parse(report_data)

        report.present? ? ::RedmineAirbrakeBackend::Error.new(report) : nil
      end

      def self.secure_type(type)
        type.to_s.gsub(/[^a-zA-Z0-9_-]/, '')
      end
    end
  end
end
