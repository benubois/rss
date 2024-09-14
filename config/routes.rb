Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "/mastodon/:search", to: "mastodon#search"
  get "/subreddit/:subreddit", to: "reddit#subreddit"
end
