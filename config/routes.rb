Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  namespace :account do
    resource :password, only: [ :edit, :update ]
  end

  resources :notifications, only: [ :index ] do
    member { patch :mark_read }
    collection { patch :mark_all_read }
  end

  # URLs stay /student/... but controllers live under Students:: to avoid
  # colliding with the Student model constant.
  namespace :student, module: "students" do
    root "dashboard#index"
    resources :achievement_requests, only: [ :new, :create, :show, :edit, :update ]
  end

  # Same module-vs-model collision avoidance as the student namespace.
  namespace :supervisor, module: "supervisors" do
    root "queue#index"
    resources :achievement_requests, only: [ :show, :new, :create, :edit, :update ] do
      member do
        patch :approve
        patch :revert
        patch :reject
      end
    end
  end

  # Directory of students with scores, visible to every faculty member.
  namespace :faculty, module: "faculties" do
    root "students#index"
    resources :students, only: [ :index, :show ]
  end

  namespace :dean, module: "deans" do
    root "queue#index"
    resources :achievement_requests, only: [ :show ] do
      member do
        patch :approve
        patch :revert
        patch :reject
      end
    end
  end

  namespace :admin do
    root "divisions#index"

    concern :archivable do
      member do
        patch :archive
        patch :restore
      end
    end

    resources :departments, :reason_templates, :users
    resources :divisions, :sub_divisions, :categories, concerns: :archivable
    resources :user_imports, only: [ :new, :create ] do
      get :template, on: :collection
    end
    resource :settings, only: [ :edit, :update ]
  end
end
