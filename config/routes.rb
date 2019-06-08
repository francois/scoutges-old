Rails.application.routes.draw do
  resources :registrations, only: %w(new create)
  resources :groups, only: %w(show) do
    resources :troops, only: %w(create)
  end
end
