require 'redmine_airbrake_backend/ios_report'

# Controller for airbrake reports
class AirbrakeReportController < ::AirbrakeController
  accept_api_auth :ios_reports

  before_action :parse_report

  # Handle airbrake iOS reports
  def ios_reports
    create_issue!

    render_airbrake_response
  end

  private

  def parse_report
    @notice = RedmineAirbrakeBackend::IosReport.new(params)
  end
end
