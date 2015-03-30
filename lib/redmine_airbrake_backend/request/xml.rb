require 'json'
require 'nokogiri'
require 'redmine_airbrake_backend/request'

module RedmineAirbrakeBackend
  class Request
    # Represents a XML request received by airbrake
    class XML < ::RedmineAirbrakeBackend::Request
      # Supported airbrake api versions
      SUPPORTED_API_VERSIONS = %w(2.4)

      class UnsupportedVersion < Error; end

      # Creates a notice from an airbrake xml request
      def self.parse(xml_data)
        doc = Nokogiri::XML(xml_data) rescue nil
        raise Invalid if doc.blank?

        notice = doc.at('//notice')
        raise Invalid if notice.blank?

        # Version
        version = notice.attributes['version']
        raise Invalid.new('No version') if version.blank? || version.value.blank?
        raise UnsupportedVersion.new(version) unless SUPPORTED_API_VERSIONS.include?(version.value)

        error_data = parse_error(notice)
        raise Invalid.new('No error found') if error_data.blank?
        error = RedmineAirbrakeBackend::Error.new(error_data)

        notifier = convert_element(notice.at('//notifier'))
        request  = parse_request(notice)
        env      = convert_element(notice.at('//server-environment'))
        config   = notice.at('//api-key').inner_text

        new(config, notifier: notifier, errors: [error], request: request, env: env)
      end

      private

      def self.parse_error(notice_doc)
        error = convert_element(notice_doc.at('//error'))

        # map class to type
        error[:type] ||= error[:class]
        error.delete(:class)

        error[:backtrace] = format_backtrace(error[:backtrace])

        error
      end

      def self.parse_request(notice_doc)
        convert_element(notice_doc.at('//request'))
      end

      def self.convert_element(elem)
        return nil if elem.nil?

        return elem.children.first.inner_text if elem.children.count == 1 && elem.children.first.is_a?(Nokogiri::XML::Text)
        return convert_attributes(elem.attributes) if elem.children.blank?
        return convert_var_elements(elem.children) if elem.children.count == elem.children.select { |c| c.name == 'var' }.count

        h = convert_children(elem)
        h.delete_if { |k, v| k.strip.blank? }
        h.symbolize_keys
      end

      def self.convert_children(elem)
        h = {}

        elem.children.each do |e|
          key = format_hash_key(e.name)

          if h.key?(key)
            h[key] = [h[key]] unless h[key].is_a?(Array)
            h[key] << convert_element(e)
          else
            h[key] = convert_element(e)
          end
        end

        h
      end

      def self.convert_var_elements(elements)
        vars = {}
        elements.each do |elem|
          vars[format_hash_key(elem.attributes['key'])] = elem.inner_text
        end
        vars.delete_if { |k, v| k.strip.blank? }
        vars.symbolize_keys
      end

      def self.format_hash_key(key)
        key.to_s.gsub(/-/, '_')
      end

      def self.convert_attributes(attributes)
        attrs = {}

        attributes.each do |k, v|
          attrs[k] = v.value
        end

        attrs.symbolize_keys
      end

      def self.ensure_hash_array(data)
        return nil if data.blank?

        d = (data.is_a?(Array) ? data : [data]).compact
        d.reject! { |e| !e.is_a?(Hash) }
        d.blank? ? nil : d
      end

      def self.format_backtrace(backtrace)
        ensure_hash_array(backtrace).first[:line] rescue nil
      end
    end
  end
end
