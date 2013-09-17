require 'json'
require 'hpricot'
require 'htmlentities'

module RedmineAirbrakeBackend
  class Notice
    SUPPORTED_API_VERSIONS = %w(2.4)

    class NoticeInvalid < StandardError; end
    class UnsupportedVersion < StandardError; end

    attr_reader :version, :params, :notifier, :error, :request, :env

    def initialize(version, params, notifier, options={})
      @version = version
      @params = params
      @notifier = notifier

      @error = options.delete(:error)
      @request = options.delete(:request)
      @env = options.delete(:env)
    end

    def self.parse(xml_data)
      doc = Hpricot::XML(xml_data)

      raise NoticeInvalid if (notice = doc.at('notice')).blank?
      raise NoticeInvalid.new('no version') if (version = notice.attributes['version']).blank?
      raise UnsupportedVersion.new(version) unless SUPPORTED_API_VERSIONS.include?(version)

      params = JSON.parse(notice.at('api-key').inner_text).symbolize_keys rescue nil
      raise NoticeInvalid.new('no or invalid api-key') if params.blank?

      raise NoticeInvalid.new('no notifier') if (notifier = convert_element(notice.at('notifier'))).blank?

      raise NoticeInvalid.new('no error') if (error = convert_element(notice.at('error'))).blank?
      raise NoticeInvalid.new('no message') if error[:message].blank?

      error[:backtrace] = format_backtrace(error[:backtrace])

      request = convert_element(notice.at('request'))
      if request[:session].present?
        request[:session][:log] = request[:session][:log].present? ? format_session_log(request[:session][:log]) : nil
      end

      env = convert_element(notice.at('server-environment'))

      new(version, params, notifier, error: error, request: request, env: env)
    end

    private

    def self.convert_element(elem)
      return nil if elem.nil?

      return elem.children.first.inner_text if !elem.children.nil? && elem.children.count == 1 && elem.children.first.is_a?(Hpricot::Text)

      return elem.attributes.to_hash.symbolize_keys if elem.children.nil?

      return convert_var_elements(elem.children) if elem.children.count == elem.children.select{|c| c.name == 'var'}.count

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
      h.delete_if{|k,v| k.strip.blank?}
      h.symbolize_keys
    end

    def self.convert_var_elements(elements)
      vars = {}
      elements.each do |elem|
        vars[format_hash_key(elem.attributes['key'])] = elem.inner_text
      end
      vars.delete_if{|k,v| k.strip.blank?}
      vars.symbolize_keys
    end

    def self.format_hash_key(key)
      key.to_s.gsub(/-/, '_')
    end

    def self.ensure_hash_array(data)
      return nil if data.blank?

      d = (data.is_a?(Array) ? data : [data]).compact
      d.reject!{|e| !e.is_a?(Hash)}
      d.blank? ? nil : d
    end

    def self.format_backtrace(backtrace)
      ensure_hash_array(backtrace).first[:line] rescue nil
    end

    def self.format_session_log(log)
      log = JSON.parse(log) rescue nil
      return nil unless log = ensure_hash_array(log)

      log.map!{|l| l.symbolize_keys!; l[:time] = (Time.parse(l[:time]) rescue nil); l}
      log.reject!{|l| l[:time].blank?}

      log.blank? ? nil : log
    end

  end
end
