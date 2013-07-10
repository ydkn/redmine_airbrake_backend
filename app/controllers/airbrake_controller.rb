require 'redmine_airbrake_backend/notice'

class AirbrakeController < ::ApplicationController
  prepend_before_filter :parse_notice_and_api_auth
  before_filter :load_records

  accept_api_auth :notice

  def notice
    return unless authorize(:issues, :create)

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
        description: render_description,
        assigned_to: @assignee
      ) unless @issue

    custom_field_values = {}

    # Update occurrences
    occurrences_value = @issue.custom_value_for(occurrences_field.id)
    custom_field_values[occurrences_field.id] = ((occurrences_value ? occurrences_value.value.to_i : 0) + 1).to_s if occurrences_field.present?

    # Reopen if closed
    if reopen? && @issue.status.is_closed?
      @issue.status = IssueStatus.where(is_default: true).order(:position).first
      @issue.init_journal(User.current, "Issue reopened after occurring again in environment #{@notice.env[:environment_name]}")
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

  def parse_notice_and_api_auth
    @notice = RedmineAirbrakeBackend::Notice.parse(request.body)
    params[:key] = @notice.params[:api_key]
  rescue RedmineAirbrakeBackend::Notice::NoticeInvalid, RedmineAirbrakeBackend::Notice::UnsupportedVersion
    render nothing: true, status: :bad_request
  end

  def load_records
    # Project
    unless @project = Project.where(identifier: @notice.params[:project]).first
      render nothing: true, status: :bad_request
      return
    end

    # Tracker
    unless (@tracker = record_for(@project.trackers, :tracker)) && @tracker.custom_fields.where(id: notice_hash_field.id).first
      render nothing: true, status: :bad_request
      return
    end

    # Category
    @category = record_for(@project.issue_categories, :category)

    # Priority
    @priority = record_for(IssuePriority, :priority) || IssuePriority.default

    # Assignee
    @assignee = record_for(@project.users, :assignee, [:id, :login])
  end

  def record_for(on, param_key, fields=[:id, :name])
    fields.each do |field|
      val = on.where(field => @notice.params[param_key]).first
      return val if val.present?
    end

    project_setting(param_key)
  end

  def project_setting(key)
    return nil if @project.airbrake_settings.blank?
    @project.airbrake_settings.send(key) if @project.airbrake_settings.respond_to?(key)
  end

  def subject
    if @notice.error[:message].starts_with?("#{@notice.error[:class]}:")
      "[#{notice_hash[0..7]}] #{@notice.error[:message]}"[0..254]
    else
      "[#{notice_hash[0..7]}] #{@notice.error[:class]} #{@notice.error[:message]}"[0..254]
    end
  end

  def notice_hash
    h = []
    h << @notice.error[:class]
    h << @notice.error[:message]
    h += normalized_backtrace if @notice.error[:backtrace].present?

    Digest::MD5.hexdigest(h.compact.join("\n"))
  end

  def normalized_backtrace
    @notice.error[:backtrace].collect do |e|
      "#{e[:file]}|#{e[:method].gsub(/_\d+_/, '')}|#{e[:number]}"
    end
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
    return false if @notice.env.blank? || @notice.env[:environment_name].blank? || project_setting(:reopen_regexp).blank?
    !!(@notice.env[:environment_name] =~ /#{project_setting(:reopen_regexp)}/i)
  end

  def setting(key)
    Setting.plugin_redmine_airbrake_backend[key]
  end

  def render_description
    if template_exists?("issue_description_#{@notice.params[:type]}", 'airbrake', true)
      render_to_string(partial: "issue_description_#{@notice.params[:type]}")
    else
      render_to_string(partial: 'issue_description')
    end
  end

end
