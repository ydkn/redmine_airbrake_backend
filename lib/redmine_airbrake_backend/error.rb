require 'digest/md5'

module RedmineAirbrakeBackend
  # Error received by airbrake
  class Error
    attr_accessor :request
    attr_reader :type, :message, :backtrace
    attr_reader :application, :airbrake_hash, :subject, :attachments

    def initialize(error_data)
      # Data
      @data = error_data

      # Type
      @type = @data[:type]

      # Message
      @message = @data[:message]

      # Backtrace
      @backtrace = @data[:backtrace]

      # Application
      @application = @data[:application]

      # Attachments
      @attachments = @data[:attachments]

      # Hash
      @airbrake_hash = generate_hash

      # Subject
      @subject = generate_subject
    end

    private

    def generate_hash
      h = []
      h << filter_hex_values(@type)
      h << filter_hex_values(@message)
      h += normalized_backtrace

      Digest::MD5.hexdigest(h.compact.join("\n"))
    end

    def generate_subject
      s = ''

      if @type.blank? || @message.starts_with?("#{@type}:")
        s = "[#{@airbrake_hash[0..7]}] #{@message}"
      else
        s = "[#{@airbrake_hash[0..7]}] #{@type}: #{@message}"
      end

      s[0..254].strip
    end

    def normalized_backtrace
      if @backtrace.present?
        @backtrace.map do |e|
          "#{e[:file]}|#{normalize_method_name(e[:method])}|#{e[:number]}" rescue nil
        end.compact
      else
        []
      end
    end

    def normalize_method_name(method_name)
      name = e[:method]
        .downcase
        .gsub(/_\d+_/, '') # ruby blocks

      filter_hex_values(name)
    end

    def filter_hex_values(value)
      value.gsub(/0x[0-9a-f]+/, '')
    end
  end
end
