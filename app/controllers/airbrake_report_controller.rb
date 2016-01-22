require 'redmine_airbrake_backend/ios_report'


# Controller for airbrake reports
class AirbrakeReportController < ::AirbrakeController
  accept_api_auth :ios_reports

  # Handle airbrake iOS reports
  def ios_reports
    error = RedmineAirbrakeBackend::IosReport.new(params[:report])

    @issue = find_or_initialize_issue(error)

    set_issue_custom_field_values(@issue, error)

    reopen_issue(@issue, error) if @issue.persisted? && @issue.status.is_closed? && reopen_issue?

    unless @issue.save
      render json: {}

      return
    end

    render json: {
      id:  (CustomValue.find_by(customized_type: Issue.name, customized_id: @issue.id, custom_field_id: notice_hash_field.id).value rescue nil),
      url: issue_url(@issue)
    }
  end
end
