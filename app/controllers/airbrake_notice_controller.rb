# Controller for airbrake notices
class AirbrakeNoticeController < ::AirbrakeController
  accept_api_auth :notices

  before_action :parse_notice

  # Handle airbrake notices
  def notices
    create_issue!

    render_airbrake_response
  end

  private

  def parse_notice
    @notice = RedmineAirbrakeBackend::Notice.new(
        errors:      params[:errors].map { |e| RedmineAirbrakeBackend::Error.new(e) },
        params:      params[:params],
        session:     params[:session],
        context:     params[:context],
        environment: params[:environment]
      )
  end
end
