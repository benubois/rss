require "net/http"

class RedditController < ApplicationController
  API_BASE_URL = "https://oauth.reddit.com"
  TOKEN_URL = "https://www.reddit.com/api/v1/access_token"
  TOKEN_CACHE_KEY = "reddit:access_token".freeze

  def subreddit
    listing = fetch_listing(params[:subreddit])
    render json: feed(listing)
  end

  private

  def fetch_listing(subreddit)
    uri = URI("#{API_BASE_URL}/r/#{subreddit}")
    response = HttpRequest.new(uri, headers: {
      "Authorization" => "Bearer #{access_token}"
    }).get
    JSON.parse(response.body)
  end

  # Application-only OAuth (client_credentials). The token is cached until just
  # before it expires, so we re-authenticate at most once per token lifetime
  # rather than on every request.
  def access_token
    Rails.cache.read(TOKEN_CACHE_KEY) || fetch_and_cache_token
  end

  def fetch_and_cache_token
    body = request_token
    ttl = [ body.fetch("expires_in", 3600).to_i - 60, 60 ].max
    Rails.cache.write(TOKEN_CACHE_KEY, body["access_token"], expires_in: ttl)
    body["access_token"]
  end

  def request_token
    response = HttpRequest.new(URI(TOKEN_URL), headers: {
      "Authorization" => "Basic #{client_credentials}",
      "Content-Type" => "application/x-www-form-urlencoded"
    }).post("grant_type=client_credentials")

    raise "Reddit authentication failed: #{response.body}" unless response.code == "200"

    JSON.parse(response.body)
  end

  def client_credentials
    creds = Rails.application.credentials
    [ "#{creds.reddit_client_id!}:#{creds.reddit_client_secret!}" ].pack("m0")
  end

  def items(search_results)
    items = []

    search_results["data"]["children"].each do |post|
      items << item(RedditPost.new(post))
    end

    items
  end

  def feed(search_results)
    {
      version: "https://jsonfeed.org/version/1.1",
      title: params[:subreddit],
      home_page_url: "https://www.reddit.com",
      feed_url: "https://www.reddit.com/r/#{params[:subreddit]}",
      items: items(search_results)
    }
  end

  def item(post)
    {
      id: post.id,
      url: post.url,
      title: post.title,
      content_html: ApplicationController.render("reddit/content", locals: { post: post }, layout: nil),
      date_published: post.published,
      authors: [
        {
          name: post.author,
          url: "https://old.reddit.com/user/#{post.author}"
        }
      ]
    }
  end
end
