Rails.application.routes.draw do
  devise_for :users, skip: [ :passwords ], controllers: { sessions: "users/sessions" }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
  resource :profile, only: [ :show, :update ]

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
    resources :achievement_requests, only: [ :new, :create, :show, :edit, :update ] do
      member do
        delete "proofs/:signed_id", action: :remove_proof, as: :proof
      end
      collection do
        get :submitted
      end
    end
  end

  # Same module-vs-model collision avoidance as the student namespace.
  namespace :supervisor, module: "supervisors" do
    root "dashboard#index"
    get "queue", to: "queue#index", as: :queue
    resources :review_histories, only: [ :index, :show ]
    resources :achievement_requests, only: [ :show, :new, :create, :edit, :update ] do
      member do
        patch :approve
        patch :revert
        patch :reject
        delete "proofs/:signed_id", action: :remove_proof, as: :proof
      end
    end
  end

  # Directory of students with scores, visible to every faculty member.
  # Dashboard is the faculty root; students list stays at /faculty/students.
  namespace :faculty, module: "faculties" do
    root "dashboard#index"
    resources :students, only: [ :index, :show ]
  end

  namespace :dean, module: "deans" do
    root "dashboard#index"
    get "queue", to: "queue#index", as: :queue
    resources :review_histories, only: [ :index, :show ]
    resources :achievement_requests, only: [ :show ] do
      member do
        patch :approve
        patch :revert
        patch :reject
      end
    end
  end

  namespace :admin do
    root "dashboard#index"

    concern :archivable do
      member do
        patch :archive
        patch :restore
      end
    end

    resources :departments, :reason_templates, :users
    resources :categories, concerns: :archivable
    resources :review_roles
    resources :role_assignments
    resources :divisions, concerns: :archivable do
      resources :hierarchy_steps, only: [ :index, :create, :update, :destroy ] do
        member do
          patch :move_up
          patch :move_down
        end
        collection { post :bulk_apply }
      end
    end
    resources :sub_divisions, concerns: :archivable do
      resources :hierarchy_steps, only: [ :index, :create, :update, :destroy ] do
        member do
          patch :move_up
          patch :move_down
        end
        collection { post :bulk_apply }
      end
    end
    resources :user_imports, only: [ :new, :create ] do
      get :template, on: :collection
    end
    resource :settings, only: [ :edit, :update ]
  end

  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#unprocessable", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

  match "*unmatched", to: "errors#not_found", via: :all
end
