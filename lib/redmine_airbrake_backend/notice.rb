require 'redmine_airbrake_backend/error'


module RedmineAirbrakeBackend
  # Notice received by airbrake
  class Notice
    attr_reader :id, :subject, :type, :environment_name
    attr_reader :errors, :params, :session, :context, :environment, :application, :attachments

    def initialize(options)
      # Errors
      @errors = options[:errors].compact

      # Params
      @params = options[:params]

      # Session
      @session = options[:session]

      # Context
      @context = options[:context].reject { |k, v| ['notifier'].include?(k) }

      # Environment
      @environment = options[:environment]

      # Application
      @application = options[:application]

      # Attachments
      @attachments = (options[:attachments].presence || []).compact

      # Environment name
      @environment_name = options[:context][:environment].presence rescue nil

      # Type
      @type = options[:type] || (options[:context][:language].split('/', 2).first.downcase rescue nil)

      # Error ID
      @id = generate_id

      # Subject
      @subject = generate_subject
    end

    private

    def generate_id
      Digest::MD5.hexdigest(@errors.join("\n"))
    end

    def generate_subject
      error = @errors.first
      s     = ''

      if error.type.blank? || error.message.starts_with?("#{error.type}:")
        s = "[#{@id[0..7]}] #{error.message}"
      else
        s = "[#{@id[0..7]}] #{error.type}: #{error.message}"
      end

      s[0..254].strip
    end
  end
end
