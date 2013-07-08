require 'json'
require 'hpricot'
require 'htmlentities'

class AirbrakeController < ::ApplicationController
  SUPPORTED_API_VERSIONS = %w(2.4)

  prepend_before_filter :set_api_auth
  before_filter :parse_notice

  accept_api_auth :notice

  def notice
    raise ArgumentError.new("Airbrake version not supported") unless SUPPORTED_API_VERSIONS.include?(@notice[:version])

    # Project
    @project = Project.where(identifier: redmine_params[:project]).first
    raise ArgumentError.new("Project not found") unless @project

    return unless authorize(:issues, :create)

    # Tracker
    @tracker = @project.trackers.where(id: redmine_params[:tracker]).first || @project.trackers.where(name: redmine_params[:tracker]).first || project_setting(:tracker)
    raise ArgumentError.new("Tracker not found") unless @tracker
    raise ArgumentError.new("Tracker does not have a notice hash custom field") unless @tracker.custom_fields.where(id: notice_hash_field.id).first

    # Category / Priority / Assignee
    @category = @project.issue_categories.where(id: redmine_params[:category]).first || @project.issue_categories.where(name: redmine_params[:category]).first || project_setting(:category)
    @priority = IssuePriority.where(id: redmine_params[:priority]).first || IssuePriority.where(name: redmine_params[:priority]).first || project_setting(:priority) || IssuePriority.default
    @assignee = @project.users.where(login: redmine_params[:assignee]).first

    # Issue by project, tracker and hash
    issue_ids = CustomValue.where(customized_type: Issue.name, custom_field_id: notice_hash_field.id, value: notice_hash).select([:customized_id]).collect{|cv| cv.customized_id}
    @issue = Issue.where(id: issue_ids, project_id: @project.id, tracker_id: @tracker.id).first
    @issue = Issue.new(
        subject: subject,
        project: @project,
        tracker: @tracker,
        author: User.current,
        category: @category,
        priority: @priority,
        description: render_to_string(partial: 'issue_description'),
        assigned_to: @assignee
      ) unless @issue

    custom_field_values = {}

    # Update occurrences
    occurrences_value = @issue.custom_value_for(occurrences_field.id)
    custom_field_values[occurrences_field.id] = ((occurrences_value ? occurrences_value.value.to_i : 0) + 1).to_s if occurrences_field.present?

    # Reopen if closed
    if reopen? && @issue.status.is_closed?
      @issue.status = IssueStatus.where(is_default: true).order(:position).first
      @issue.init_journal(User.current, "Issue reopened after occurring again in environment #{@notice[:server_environment][:environment_name]}")
    end

    # Hash
    custom_field_values[notice_hash_field.id] = notice_hash if @issue.new_record?

    @issue.custom_field_values = custom_field_values

    if @issue.save
      render xml: {
        notice: {
          id: notice_hash,
          url: issue_url(@issue)
        }
      }
    else
      render nothing: true, status: :internal_server_error
    end
  end

  private

  def set_api_auth
    params[:key] = redmine_params[:api_key] rescue nil
  end

  def redmine_params
    JSON.parse(params[:notice][:api_key]).symbolize_keys
  end
  helper_method :redmine_params

  def subject
    if @notice[:error][:message].starts_with?("#{@notice[:error][:class]}:")
      "[#{notice_hash[0..7]}] #{@notice[:error][:message]}"[0..254]
    else
      "[#{notice_hash[0..7]}] #{@notice[:error][:class]} #{@notice[:error][:message]}"[0..254]
    end
  end

  def backtrace
    if @notice[:error][:backtrace][:line].is_a?(Hash)
      [@notice[:error][:backtrace][:line]]
    else
      @notice[:error][:backtrace][:line]
    end
  end
  helper_method :backtrace

  def notice_hash
    h = []
    h << @notice[:error][:class]
    h << @notice[:error][:message]
    h += backtrace.collect{|element| "#{element[:file]}|#{element[:method].gsub(/_\d+_/, '')}|#{element[:number]}"}

    Digest::MD5.hexdigest(h.compact.join("\n"))
  end

  def notice_hash_field
    custom_field(:hash_field)
  end

  def occurrences_field
    custom_field(:occurrences_field)
  end

  def custom_field(key)
    @project.issue_custom_fields.where(id: setting(key)).first || CustomField.where(id: setting(key), is_for_all: true).first
  end

  def reopen?
    return false if project_setting(:reopen_regexp).blank?
    !!(@notice[:server_environment][:environment_name] =~ /#{project_setting(:reopen_regexp)}/i)
  end

  def setting(key)
    Setting.plugin_redmine_airbrake_backend[key]
  end

  def project_setting(key)
    @project.airbrake_settings.send(key) if @project.airbrake_settings.respond_to?(key)
  end

  def parse_notice
    @notice = params[:notice]

    return @notice if @notice[:request].blank?

    doc = Hpricot::XML(request.body)

    unless @notice[:request][:params].blank?
      request_params = convert_var_elements(doc/'/notice/request/params/var')
      request_params.delete(:action) # already known
      request_params.delete(:controller) # already known
      @notice[:request][:params] = request_params
    end

    unless @notice[:request][:cgi_data].nil?
      cgi_data = convert_var_elements(doc/'notice/request/cgi-data/var')
      @notice[:request][:cgi_data] = cgi_data
    end

    unless @notice[:request][:session].nil?
      session_vars = convert_var_elements(doc/'/notice/request/session/var')
      @notice[:request][:session] = session_vars
    end
  rescue
    @notice = nil
    render nothing: true, status: :bad_request
  end

  def convert_var_elements(elements)
    result = {}
    elements.each do |elem|
      result[elem.attributes['key']] = elem.inner_text
    end
    result.delete_if{|k,v| k.strip.blank?}
    result.symbolize_keys
  end

end
