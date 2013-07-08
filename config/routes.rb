Rails.application.routes.draw do
  post '/notifier_api/v2/notices/' => 'airbrake#notice'

  resources :projects do
    member do
      post 'airbrake_settings' => 'airbrake_project_settings#update'
    end
  end
end
