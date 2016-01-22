Rails.application.routes.draw do
  # api
  post '/api/v3/projects/:project_id/notices'     => 'airbrake_notice#notices'
  post '/api/v3/projects/:project_id/ios-reports' => 'airbrake_report#ios_reports'

  # settings
  resources :projects do
    member do
      post 'airbrake_settings' => 'airbrake_project_settings#update'
    end
  end
end
