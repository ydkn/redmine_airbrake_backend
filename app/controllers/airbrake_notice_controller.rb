# Controller for airbrake notices
class AirbrakeNoticeController < ::AirbrakeController
  accept_api_auth :notices

  # Handle airbrake notices
  def notices
    @issue = nil

    params[:errors].each do |e|
      error = RedmineAirbrakeBackend::Error.new(e)

      issue = find_or_initialize_issue(error)

      set_issue_custom_field_values(issue, error)

      reopen_issue(issue, error) if issue.persisted? && issue.status.is_closed? && reopen_issue?

      @issue ||= issue if issue.save
    end

    if @issue.present?
      render json: {
        id:  (CustomValue.find_by(customized_type: Issue.name, customized_id: @issue.id, custom_field_id: notice_hash_field.id).value rescue nil),
        url: issue_url(@issue)
      }
    else
      render json: {}
    end
  end
end
