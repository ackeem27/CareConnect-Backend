Rails.application.routes.draw do
  # ==============================================================================
  # CARECONNECT API ROUTING DEFINITIONS
  # 
  # This file defines all the endpoints available in the backend API.
  # The API is currently versioned under the `api/v1` namespace to ensure
  # future updates don't break older mobile or frontend clients.
  #
  # See https://guides.rubyonrails.org/routing.html for Rails DSL documentation
  # ==============================================================================

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      # Health Check (NFR7)
      get "health", to: "health#show"

      # Auth
      post "auth/login", to: "auth#login"
      post "auth/forgot_password", to: "auth#forgot_password"
      post "auth/reset_password", to: "auth#reset_password"

      # Users (registration + OTP)
      resources :users, only: [:index, :create]
      patch "users/update_profile", to: "users#update_profile"
      post "users/verify_otp", to: "users#verify_otp"
      post "users/resend_otp", to: "users#resend_otp"

      # AI Prioritization
      post "prioritize", to: "prioritizations#analyze"

      # AI Evaluation & Accuracy Testing
      get "ai_evaluation/test_cases", to: "ai_evaluation#test_cases"
      post "ai_evaluation/single", to: "ai_evaluation#single"

      # Appointments
      get "appointments/my", to: "appointments#my_appointments"
      resources :appointments, only: [:create, :destroy, :update] do
        member do
          post :finalize
          post :request_lab
          post :recall_from_lab
        end
        collection do
          get :queue
          get :standby
          post :auto_schedule
          post :walkin
          delete :clear_all
        end
      end

      # Lab Requests
      get "lab_requests/pending", to: "lab_requests#pending"
      post "lab_requests/:id/submit_results", to: "lab_requests#submit_results"

      # Schedule Management
      get "schedule", to: "schedule#index"
      post "schedule/approve/:id", to: "schedule#approve"
      post "schedule/reject/:id", to: "schedule#reject"
      patch "schedule/override/:id", to: "schedule#override"
      patch "schedule/reschedule/:id", to: "schedule#reschedule"
      patch "schedule/swap/:id", to: "schedule#swap"

      # Notifications
      resources :notifications, only: [:index] do
        member do
          patch :mark_read
        end
        collection do
          post :mark_all_read
          delete :clear
        end
      end

      # Admin
      namespace :admin do
        get :stats
        get :users
        patch "users/:id", to: "/api/v1/admin#update_user", as: :update_user
        delete "users/:id", to: "/api/v1/admin#deactivate_user", as: :deactivate_user
        patch "users/:id/reactivate", to: "/api/v1/admin#reactivate_user", as: :reactivate_user
        get :activity_logs
        get :configs
        patch "configs/:id", to: "/api/v1/admin#update_config", as: :update_config
        get :audit_summary
      end
    end
  end
end
