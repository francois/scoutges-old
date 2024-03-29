Rails.application.routes.draw do
  resources :groups, only: %w(show) do
    resources :enrollments, only: %w(create destroy)
    resources :events, except: %w(destroy)
    resources :members, only: %w(create)
    resources :products
    resources :troops, only: %w(create)
  end

  resources :registrations, only: %w(new create)

  resources :blobs, only: %w(show destroy)

  root to: "home#index"
end
