Rails.application.routes.draw do
  resources :groups, only: %w(show) do
    resources :enrollments, only: %w(create)
    resources :events, only: %w(new create show)
    resources :members, only: %w(create)
    resources :troops, only: %w(create)
  end

  resources :registrations, only: %w(new create)
end