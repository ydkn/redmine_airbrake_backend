require File.expand_path('../../test_helper', __FILE__)

class NoticeTest < ActiveSupport::TestCase
  test 'parse' do
    api_key = {
      api_key: 'foobar',
      project: 'foo'
    }.to_json
    xml_data = <<-EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <notice version="2.4">
        <api-key>#{api_key}</api-key>
        <notifier>
          <name>Airbrake Notifier</name>
          <version>3.1.6</version>
          <url>http://api.airbrake.io</url>
        </notifier>
        <error>
          <class>RuntimeError</class>
          <message>RuntimeError: I've made a huge mistake</message>
          <backtrace>
            <line method="public" file="/testapp/app/models/user.rb" number="53"/>
            <line method="index" file="/testapp/app/controllers/users_controller.rb" number="14"/>
          </backtrace>
        </error>
        <request>
          <url>http://example.com</url>
          <component/>
          <action/>
          <cgi-data>
            <var key="SERVER_NAME">example.org</var>
            <var key="HTTP_USER_AGENT">Mozilla</var>
          </cgi-data>
        </request>
        <server-environment>
          <project-root>/testapp</project-root>
          <environment-name>production</environment-name>
          <app-version>1.0.0</app-version>
        </server-environment>
      </notice>
    EOS

    notice = RedmineAirbrakeBackend::Notice.parse(prepare_xml(xml_data))
    assert notice
  end

  private

  def prepare_xml(xml_data)
    xml_data.split("\n").map { |l| l.strip }.join('')
  end
end
