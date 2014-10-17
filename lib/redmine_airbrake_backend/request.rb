require 'json'
require 'base64'
require 'redmine_airbrake_backend/error'

module RedmineAirbrakeBackend
  # Represents a request received by airbrake
  class Request
    class Error < StandardError; end
    class Invalid < Error; end

    attr_reader :api_key, :project, :tracker, :category, :priority, :assignee, :repository, :type
    attr_reader :params, :notifier, :errors, :context, :request, :env
    attr_reader :environment_name

    def initialize(config, data = {})
      # config
      @config = self.class.parse_config(config)
      raise Invalid.new('Encoded configuration in api-key is missing') if @config.blank?

      # API key
      @api_key = @config[:api_key]
      raise Invalid.new('No or invalid api-key') if @api_key.blank?

      # Project
      @project = Project.where(identifier: @config[:project]).first
      raise Invalid.new('No or invalid project') if @project.blank?
      raise Invalid.new('Airbrake not enabled for project') if @project.enabled_modules.where(name: :airbrake).empty?

      # Check configuration
      raise Invalid.new('Custom field for notice hash is not configured!') if notice_hash_field.blank?

      # Tracker
      @tracker = record_for(@project.trackers, :tracker)
      raise Invalid.new('No or invalid tracker') if @tracker.blank?
      raise Invalid.new('Custom field for notice hash not available on selected tracker') if @tracker.custom_fields.where(id: notice_hash_field.id).first.blank?

      # Category
      @category = record_for(@project.issue_categories, :category)

      # Priority
      @priority = record_for(IssuePriority, :priority) || IssuePriority.default

      # Assignee
      @assignee = record_for(@project.users, :assignee, [:id, :login])

      # Repository
      @repository = @project.repositories.where(identifier: (@config[:repository] || '')).first

      # Type
      @type = @config[:type]

      # Errors
      @errors = (data[:errors] || [])
      @errors.each { |e| e.request = self }

      # Environment
      @env = data[:env]

      # Request
      @request = data[:request]

      # Context
      @context = data[:context]

      # Notifier
      @notifier = data[:notifier]

      # Params
      @params = data[:params]

      # Environment name
      @environment_name   = (@env[:environment_name].presence || @env[:name].presence) if @env.present?
      @environment_name ||= @context[:environment].presence if @context.present?
    end

    def notice_hash_field
      custom_field(:hash_field)
    end

    def occurrences_field
      custom_field(:occurrences_field)
    end

    def reopen?
      reopen_regexp = project_setting(:reopen_regexp)

      return false if environment_name.blank? || reopen_regexp.blank?

      !!(environment_name =~ /#{reopen_regexp}/i)
    end

    def reopen_repeat_description?
      !!project_setting(:reopen_repeat_description)
    end

    private

    def record_for(on, config_key, fields = [:id, :name])
      fields.each do |field|
        val = on.where(field => @config[config_key]).first
        return val if val.present?
      end

      project_setting(config_key)
    end

    def project_setting(key)
      return nil if @project.airbrake_settings.blank?

      @project.airbrake_settings.send(key) if @project.airbrake_settings.respond_to?(key)
    end

    def custom_field(key)
      @project.issue_custom_fields.where(id: global_setting(key)).first || CustomField.where(id: global_setting(key), is_for_all: true).first
    end

    def global_setting(key)
      Setting.plugin_redmine_airbrake_backend[key]
    end

    def self.parse_config(api_key_data)
      config = ::JSON.parse(api_key_data).symbolize_keys rescue nil

      return config.symbolize_keys if config.is_a?(Hash)

      config = ::JSON.parse(Base64.decode64(api_key_data)) rescue nil

      return config.symbolize_keys if config.is_a?(Hash)

      nil
    end
  end
end
