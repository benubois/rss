class BlueskyController < ApplicationController
  BLUESKY_BASE_URL = "https://bsky.social"

  def user
    username = params[:username]
    access_token = authenticate

    bsky_url = URI("#{BLUESKY_BASE_URL}/xrpc/app.bsky.feed.getAuthorFeed")
    bsky_url.query = URI.encode_www_form({ actor: username })

    response = HttpRequest.new(bsky_url, headers: {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{access_token}"
    }).get

    # Handle unauthorized response
    if response.code == "401"
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    posts = JSON.parse(response.body)

    render json: to_feed(username, posts["feed"])
  end

  def search
    query = params[:query]
    access_token = authenticate

    bsky_url = URI("#{BLUESKY_BASE_URL}/xrpc/app.bsky.feed.searchPosts")
    bsky_url.query = URI.encode_www_form({ q: query })

    response = HttpRequest.new(bsky_url, headers: {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{access_token}"
    }).get

    if response.code == "401"
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    posts = JSON.parse(response.body)

    render json: to_feed(query, posts["posts"])
  end

  def to_feed(username, posts)
    feed = {
      version: "https://jsonfeed.org/version/1",
      title: "@#{username}",
      home_page_url: "https://bsky.app/profile/#{username}",
      feed_url: "",
      items: []
    }

    posts.each do |post|
      feed[:items] << {
        id: post["uri"],
        url: "https://bsky.app/profile/#{post["author"]["handle"]}/post/#{post["uri"].split("/").last}",
        content_html: ApplicationController.render("bluesky/content", locals: {post: post}, layout: nil),
        date_published: post["record"]["createdAt"],
        authors: [
          {
            name: post["author"]["displayName"],
            url: "https://bsky.app/profile/#{post["author"]["handle"]}",
            avatar: post["author"]["avatar"],
            _social: {
              username: post["author"]["handle"]
            }
          }
        ]
      }
    end

    feed
  end

  private

  def authenticate
    auth_url = URI("#{BLUESKY_BASE_URL}/xrpc/com.atproto.server.createSession")

    response = HttpRequest.new(auth_url, headers: {
      "Content-Type" => "application/json"
    })
    .post({
      identifier: Rails.application.credentials.bluesky_handle,
      password: Rails.application.credentials.bluesky_access_token
    }.to_json)

    if response.code == "200"
      JSON.parse(response.body)["accessJwt"]
    else
      raise "Authentication failed: #{response.body}"
    end
  end
end
