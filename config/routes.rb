Rails.application.routes.draw do
  # notifier api
  post '/notifier_api/v2/notices'       => 'airbrake_notice#notice_xml'
  post '/notifier_api/v3/notices'       => 'airbrake_notice#notice_json'
  post '/notifier_api/v3/reports/:type' => 'airbrake_report#report'

  # settings
  resources :projects do
    member do
      post 'airbrake_settings' => 'airbrake_project_settings#update'
    end
  end
end
