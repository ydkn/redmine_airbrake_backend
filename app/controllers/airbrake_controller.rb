require 'tempfile'
require 'redmine_airbrake_backend/notice'

# Controller with airbrake related stuff
class AirbrakeController < ::ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :session_expiration, :user_setup, :check_if_login_required, :set_localization, :check_password_change

  prepend_before_action :find_project
  prepend_before_action :parse_key

  before_action :authorize
  before_action :find_tracker
  before_action :find_category
  before_action :find_priority
  before_action :find_assignee
  before_action :find_repository

  after_action :cleanup_tempfiles

  private

  def find_project
    @project = Project.find(@key[:project] || params[:project_id])
  end

  def parse_key
    @key = nil

    if (request.headers['HTTP_AUTHORIZATION'] || '') =~ /^Bearer\s+(.*)\s*$/i
      # New auth method
      @key = JSON.parse(Regexp.last_match[1]).with_indifferent_access rescue nil
    elsif params[:key].present?
      # Old auth method
      @key = JSON.parse(params[:key]).with_indifferent_access rescue nil
    end

    render_error('No or invalid API key format', :unauthorized) if @key.blank? || @key[:key].blank?
  end

  def authorize
    User.current = User.find_by_api_key(@key[:key])

    if User.current.blank? || User.current.anonymous?
      render_error('Failed to authenticate', :unauthorized)

      return
    end

    return if User.current.allowed_to?({ controller: params[:controller], action: params[:action] }, @project)

    render_error('Access Denied', :forbidden)
  end

  def find_tracker
    @tracker = record_for(@project.trackers, :tracker)

    render_error('No or invalid tracker', :failed_dependency) if @tracker.blank?

    # Check notice ID field
    render_error('Custom field for notice hash not available on selected tracker', :failed_dependency) if @tracker.custom_fields.find_by(id: notice_hash_field.id).blank?
  end

  def find_category
    @category = record_for(@project.issue_categories, :category)
  end

  def find_priority
    @priority = record_for(IssuePriority, :priority) || IssuePriority.default
  end

  def find_assignee
    @assignee = record_for(@project.users, :assignee, [:id, :login])
  end

  def find_repository
    @repository = @project.repositories.find_by(identifier: (@key[:repository] || ''))
  end

  def render_error(error, status = :internal_server_error)
    ::Rails.logger.warn(error)

    render json: { error: { message: error } }, status: status
  end

  def render_airbrake_response
    if @issue.present?
      render json: {
        id:  (CustomValue.find_by(customized_type: Issue.name, customized_id: @issue.id, custom_field_id: notice_hash_field.id).value rescue nil),
        url: issue_url(@issue)
      }, status: :created
    else
      render json: {}
    end
  end

  def record_for(on, key, fields = [:id, :name])
    fields.each do |field|
      val = on.find_by(field => @key[key])
      return val if val.present?
    end

    project_setting(key)
  end

  def global_setting(key)
    Setting.plugin_redmine_airbrake_backend[key.to_s]
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

  def create_issue!
    return if @notice.blank?
    return if @notice.errors.blank?

    @issue = find_or_initialize_issue(@notice)

    set_issue_custom_field_values(@issue, @notice)

    reopen_issue(@issue, @notice) if @issue.persisted? && @issue.status.is_closed? && reopen_issue?(@notice)

    @issue = nil unless @issue.save
  end

  # Load or initialize issue by project, tracker and airbrake hash
  def find_or_initialize_issue(notice)
    issue_ids = CustomValue.where(customized_type: Issue.name, custom_field_id: notice_hash_field.id, value: notice.id).pluck(:customized_id)

    issue = Issue.find_by(id: issue_ids, project_id: @project.id, tracker_id: @tracker.id)

    return issue if issue.present?

    initialize_issue(notice)
  end

  def initialize_issue(notice)
    issue = Issue.new(
        subject: notice.subject,
        project: @project,
        tracker: @tracker,
        author: User.current,
        category: @category,
        priority: @priority,
        description: render_description(notice),
        assigned_to: @assignee
      )

    add_attachments_to_issue(issue, notice)

    issue
  end

  def set_issue_custom_field_values(issue, notice)
    custom_field_values = {}

    # Error ID
    custom_field_values[notice_hash_field.id] = notice.id if issue.new_record?

    # Update occurrences
    if occurrences_field.present?
      occurrences_value = issue.custom_value_for(occurrences_field.id)
      custom_field_values[occurrences_field.id] = ((occurrences_value ? occurrences_value.value.to_i : 0) + 1).to_s
    end

    issue.custom_field_values = custom_field_values
  end

  def add_attachments_to_issue(issue, notice)
    return if notice.attachments.blank?

    @tempfiles ||= []

    notice.attachments.each do |data|
      filename = data[:filename].presence || Redmine::Utils.random_hex(16)

      file = Tempfile.new(filename)
      @tempfiles << file

      file.write(data[:data])
      file.rewind

      issue.attachments << Attachment.new(file: file, author: User.current, filename: filename)
    end
  end

  def reopen_issue?(notice)
    reopen_regexp = project_setting(:reopen_regexp)

    return false if reopen_regexp.blank?
    return false if notice.environment_name.blank?

    !!(notice.environment_name =~ /#{reopen_regexp}/i)
  end

  def issue_reopen_repeat_description?
    !!project_setting(:reopen_repeat_description)
  end

  def reopen_issue(issue, notice)
    return if notice.environment_name.blank?

    desc = "*Issue reopened after occurring again in _#{notice.environment_name}_ environment.*"
    desc << "\n\n#{render_description(notice)}" if issue_reopen_repeat_description?

    issue.status = issue.tracker.default_status

    issue.init_journal(User.current, desc)

    add_attachments_to_issue(issue, notice)
  end

  def render_description(notice)
    locals = { notice: notice }

    if template_exists?("airbrake/issue_description/#{notice.type}")
      render_to_string("airbrake/issue_description/#{notice.type}", layout: false, locals: locals)
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
