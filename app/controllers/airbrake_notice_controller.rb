# Controller for airbrake notices
class AirbrakeNoticeController < ::AirbrakeController
  accept_api_auth :notices

  # Handle airbrake notices
  def notices
    create_issues

    render_airbrake_response
  end

  private

  def create_issues
    params[:errors].each do |e|
      error = RedmineAirbrakeBackend::Error.new(e)

      issue = find_or_initialize_issue(error)

      set_issue_custom_field_values(issue, error)

      reopen_issue(issue, error) if issue.persisted? && issue.status.is_closed? && reopen_issue?

      @issue ||= issue if issue.save
    end
  end
end
