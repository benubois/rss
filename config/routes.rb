Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "/mastodon/:search", to: "mastodon#search"
  get "/bluesky/user/:username", to: "bluesky#user", username: /.*/
  get "/bluesky/:search", to: "bluesky#search"
  get "/reddit/:subreddit", to: "reddit#subreddit"
end
