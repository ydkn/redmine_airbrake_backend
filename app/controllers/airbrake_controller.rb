require 'tempfile'
require 'redmine_airbrake_backend/error'


# Controller with airbrake related stuff
class AirbrakeController < ::ApplicationController
  class InvalidRequest < StandardError; end

  skip_before_action :verify_authenticity_token

  prepend_before_action :parse_key
  prepend_before_action :find_project
  before_action :set_environment
  before_action :authorize

  after_action :cleanup_tempfiles

  rescue_from InvalidRequest, with: :render_bad_request

  private

  def find_project
    @project = Project.find(params[:project_id])
  end

  def parse_key
    @key = JSON.parse(params[:key]).symbolize_keys #rescue nil

    # API key
    raise InvalidRequest.new('No or invalid API key') if @key.blank? || @key[:key].blank?
    params[:key] = @key[:key]

    # Tracker
    @tracker = record_for(@project.trackers, :tracker)
    raise InvalidRequest.new('No or invalid tracker') if @tracker.blank?

    # Notice ID field
    raise InvalidRequest.new('Custom field for notice hash not available on selected tracker') if @tracker.custom_fields.find_by(id: notice_hash_field.id).blank?

    # Category
    @category = record_for(@project.issue_categories, :category)

    # Priority
    @priority = record_for(IssuePriority, :priority) || IssuePriority.default

    # Assignee
    @assignee = record_for(@project.users, :assignee, [:id, :login])

    # Repository
    @repository = @project.repositories.find_by(identifier: (@key[:repository] || ''))

    # Type
    @type = @key[:type] || (params[:context][:language].split('/', 2).first.downcase rescue nil)
  end

  def set_environment
    @environment = params[:context][:environment].presence rescue nil
  end

  def render_bad_request(error)
    ::Rails.logger.warn(error.message)

    render text: error.message, status: :bad_request
  end

  def record_for(on, key, fields = [:id, :name])
    fields.each do |field|
      val = on.find_by(field => @key[key])
      return val if val.present?
    end

    project_setting(key)
  end

  def global_setting(key)
    Setting.plugin_redmine_airbrake_backend[key]
  end

  def project_setting(key)
    return nil if @project.airbrake_settings.blank?

    @project.airbrake_settings.send(key) if @project.airbrake_settings.respond_to?(key)
  end

  def custom_field(key)
    @project.issue_custom_fields.find_by(id: global_setting(key)) || CustomField.find_by(id: global_setting(key), is_for_all: true)
  end

  def notice_hash_field
    custom_field(:hash_field)
  end

  def occurrences_field
    custom_field(:occurrences_field)
  end

  # Load or initialize issue by project, tracker and airbrake hash
  def find_or_initialize_issue(error)
    issue_ids = CustomValue.where(customized_type: Issue.name, custom_field_id: notice_hash_field.id, value: error.id).pluck(:customized_id)

    issue = Issue.find_by(id: issue_ids, project_id: @project.id, tracker_id: @tracker.id)

    return issue if issue.present?

    initialize_issue(error)
  end

  def initialize_issue(error)
    issue = Issue.new(
        subject: error.subject,
        project: @project,
        tracker: @tracker,
        author: User.current,
        category: @category,
        priority: @priority,
        description: render_description(error),
        assigned_to: @assignee
      )

    add_attachments_to_issue(issue, error)

    issue
  end

  def set_issue_custom_field_values(issue, error)
    custom_field_values = {}

    # Error ID
    custom_field_values[notice_hash_field.id] = error.id if issue.new_record?

    # Update occurrences
    if occurrences_field.present?
      occurrences_value = issue.custom_value_for(occurrences_field.id)
      custom_field_values[occurrences_field.id] = ((occurrences_value ? occurrences_value.value.to_i : 0) + 1).to_s
    end

    issue.custom_field_values = custom_field_values
  end

  def add_attachments_to_issue(issue, error)
    return if error.attachments.blank?

    @tempfiles ||= []

    error.attachments.each do |data|
      filename = data[:filename].presence || Redmine::Utils.random_hex(16)

      file = Tempfile.new(filename)
      @tempfiles << file

      file.write(data[:data])
      file.rewind

      issue.attachments << Attachment.new(file: file, author: User.current, filename: filename)
    end
  end

  def reopen_issue?
    reopen_regexp = project_setting(:reopen_regexp)

    return false if reopen_regexp.blank?
    return false if @environment.blank?

    !!(@environment =~ /#{reopen_regexp}/i)
  end

  def issue_reopen_repeat_description?
    !!project_setting(:reopen_repeat_description)
  end

  def reopen_issue(issue, error)
    return if @environment.blank?

    desc = "*Issue reopened after occurring again in _#{@environment}_ environment.*"
    desc << "\n\n#{render_description(error)}" if issue_reopen_repeat_description?

    issue.status = issue.tracker.default_status

    issue.init_journal(User.current, desc)

    add_attachments_to_issue(issue, error)
  end

  def render_description(error)
    locals = { error: error }

    if template_exists?("airbrake/issue_description/#{@type}")
      render_to_string("airbrake/issue_description/#{@type}", layout: false, locals: locals)
    else
      render_to_string('airbrake/issue_description/default', layout: false, locals: locals)
    end
  end

  def cleanup_tempfiles
    return if @tempfiles.blank?

    @tempfiles.each do |tempfile|
      tempfile.close rescue nil
      tempfile.unlink rescue nil
    end
  end
end
