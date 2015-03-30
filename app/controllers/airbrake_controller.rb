require 'tempfile'
require 'redmine_airbrake_backend/request/xml'
require 'redmine_airbrake_backend/request/json'

# Controller with airbrake related stuff
class AirbrakeController < ::ApplicationController
  skip_before_filter :verify_authenticity_token

  before_filter :authorize_airbrake
  before_filter :handle_request

  after_filter :cleanup_tempfiles

  rescue_from RedmineAirbrakeBackend::Request::Error, with: :render_bad_request

  private

  def authorize_airbrake
    @project = @request.project

    authorize(:issues, :create)
  end

  def render_bad_request(error)
    render text: error.message, status: :bad_request
  end

  def parse_xml_request
    request.body.rewind

    @request  = RedmineAirbrakeBackend::Request::XML.parse(request.body)

    params[:key] = @request.api_key
  end

  def parse_json_request
    @request  = RedmineAirbrakeBackend::Request::JSON.parse(params)

    params[:key] = @request.api_key
  end

  def handle_request
    @tempfiles = []

    @results = []

    @request.errors.each do |error|
      issue = find_or_initialize_issue(error)

      set_custom_field_values(issue, @request, error.airbrake_hash)

      reopen_issue(issue, error) if @request.reopen? && issue.status.is_closed?

      if issue.save
        @results << {
          issue: issue,
          hash:  error.airbrake_hash
        }
      end
    end
  end

  # Load or initialize issue by project, tracker and airbrake hash
  def find_or_initialize_issue(error)
    issue_ids = CustomValue.where(customized_type: Issue.name, custom_field_id: @request.notice_hash_field.id, value: error.airbrake_hash).pluck(:customized_id)

    issue = Issue.where(id: issue_ids, project_id: @request.project.id, tracker_id: @request.tracker.id).first

    return issue if issue.present?

    issue = Issue.new(
      subject: error.subject,
      project: @request.project,
      tracker: @request.tracker,
      author: User.current,
      category: @request.category,
      priority: @request.priority,
      description: render_description(error),
      assigned_to: @request.assignee
    )

    add_error_attachments_to_issue(issue, error)

    issue
  end

  def set_custom_field_values(issue, request, airbrake_hash)
    custom_field_values = {}

    # Error hash
    custom_field_values[request.notice_hash_field.id] = airbrake_hash if issue.new_record?

    # Update occurrences
    if request.occurrences_field.present?
      occurrences_value = issue.custom_value_for(request.occurrences_field.id)
      custom_field_values[request.occurrences_field.id] = ((occurrences_value ? occurrences_value.value.to_i : 0) + 1).to_s
    end

    issue.custom_field_values = custom_field_values
  end

  def add_error_attachments_to_issue(issue, error)
    return if error.attachments.blank?

    error.attachments.each do |attachment_data|
      filename = attachment_data[:filename].presence || Redmine::Utils.random_hex(16)

      file = Tempfile.new(filename)
      @tempfiles << file

      file.write(attachment_data[:data])
      file.rewind

      attachment          = Attachment.new(file: file)
      attachment.author   = User.current
      attachment.filename = filename

      issue.attachments << attachment
    end
  end

  def reopen_issue(issue, error)
    return if @request.environment_name.blank?

    desc = "*Issue reopened after occurring again in _#{@request.environment_name}_ environment.*"
    desc << "\n\n#{render_description(error)}" if @request.reopen_repeat_description?

    issue.status = IssueStatus.where(is_default: true).order(:position).first

    issue.init_journal(User.current, desc)

    add_error_attachments_to_issue(issue, error)
  end

  def render_description(error)
    locals = { request: @request, error: error }

    if template_exists?("airbrake/issue_description/#{@request.type}")
      render_to_string("airbrake/issue_description/#{@request.type}", layout: false, locals: locals)
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
