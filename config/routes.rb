Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # TTS Routes
  root "tts#index"
  resources :speech_requests, only: [:show], controller: 'tts' do
    get 'download/:provider', to: 'tts#download', as: :download
    member do
      patch :cancel, to: 'tts#cancel'
      patch :retry, to: 'tts#retry_request'
    end
  end
  post 'tts', to: 'tts#create'
  
  # Mock S3 serve route (development only)
  if Rails.env.development?
    get 'mock_s3/*path', to: 'tts#serve_mock_s3', constraints: { path: /.*/ }
  end
  
  # Sidekiq Web UI (for development/staging)
  if Rails.env.development?
    begin
      require 'sidekiq/web'
      mount Sidekiq::Web => '/sidekiq'
    rescue LoadError
      # Sidekiq gem not available, skip mounting
    end
  end
end
