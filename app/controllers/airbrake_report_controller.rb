require 'redmine_airbrake_backend/ios_report'


# Controller for airbrake reports
class AirbrakeReportController < ::AirbrakeController
  accept_api_auth :ios_reports

  # Handle airbrake iOS reports
  def ios_reports
    create_issue

    render_airbrake_response
  end

  private

  def create_issue
    error = RedmineAirbrakeBackend::IosReport.new(params[:report])

    @issue = find_or_initialize_issue(error)

    set_issue_custom_field_values(@issue, error)

    reopen_issue(@issue, error) if @issue.persisted? && @issue.status.is_closed? && reopen_issue?

    @issue = nil unless @issue.save
  end
end
