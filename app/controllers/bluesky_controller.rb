require "net/http"

class BlueskyController < ApplicationController
  BLUESKY_BASE_URL = "https://bsky.social"

  def user
    username = params[:username]

    access_token = authenticate

    bsky_url = URI("#{BLUESKY_BASE_URL}/xrpc/app.bsky.feed.getAuthorFeed")
    bsky_url.query = URI.encode_www_form({ actor: username })

    http = Net::HTTP.new(bsky_url.host, bsky_url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(bsky_url)
    request["Accept"] = "application/json"

    if access_token
      request["Authorization"] = "Bearer #{access_token}"
    end

    response = http.request(request)

    # Handle unauthorized response
    if response.code == "401"
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    posts = JSON.parse(response.body)

    render json: to_feed(username, posts)
  end

  def to_feed(username, posts)
    feed = {
      version: "https://jsonfeed.org/version/1",
      title: "@#{username}",
      home_page_url: "https://bsky.app/profile/#{username}",
      feed_url: "",
      items: []
    }

    posts["feed"].each do |post|
      feed[:items] << {
        id: post["post"]["uri"],
        url: "https://bsky.app/profile/#{username}/post/#{post["post"]["uri"].split("/").last}",
        content_html: ApplicationController.render("bluesky/content", locals: {post: post}, layout: nil),
        date_published: post["post"]["record"]["createdAt"],
        authors: [
          {
            name: post["post"]["author"]["displayName"],
            url: "https://bsky.app/profile/#{post["post"]["author"]["handle"]}",
            avatar: post["post"]["author"]["avatar"],
            _social: {
              username: post["post"]["author"]["handle"]
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

    http = Net::HTTP.new(auth_url.host, auth_url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(auth_url)
    request["Content-Type"] = "application/json"
    request.body = {
      identifier: Rails.application.credentials.bluesky_handle,
      password: Rails.application.credentials.bluesky_access_token
    }.to_json

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)["accessJwt"]
    else
      raise "Authentication failed: #{response.body}"
    end
  end
end
