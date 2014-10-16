# Controller for airbrake notices
class AirbrakeNoticeController < ::AirbrakeController
  prepend_before_filter :parse_xml_request,  only: [:notice_xml]
  prepend_before_filter :parse_json_request, only: [:notice_json]

  accept_api_auth :notice_xml, :notice_json

  # Handle airbrake XML notices
  def notice_xml
    render xml: {
      notice: {
        id: (@results.first[:hash] rescue nil)
      }
    }
  end

  # Handle airbrake JSON notices
  def notice_json
    render json: {
      notice: {
        id: (@results.first[:hash] rescue nil)
      }
    }
  end
end
