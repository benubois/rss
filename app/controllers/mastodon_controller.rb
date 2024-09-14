require "net/http"

class MastodonController < ApplicationController
  BASE_URL = "https://mastodon.social"

  def search
    search_results = perform_search(params[:query])
    render json: feed(search_results, params[:query])
  end

  private

  def perform_search(query)
    uri = URI("#{BASE_URL}/api/v2/search")
    uri.query = URI.encode_www_form({ q: query, limit: 20 })
    logger.info { uri }
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{Rails.application.credentials.mastodon_access_token!}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def items(search_results)
    items = []

    search_results["statuses"]&.each do |status|
      items << item(status)
    end

    items
  end

  def feed(search_results, query)
    {
      version: "https://jsonfeed.org/version/1.1",
      title: "Mastodon #{query}",
      home_page_url: BASE_URL,
      feed_url: "#{BASE_URL}/api/v2/search?q=#{URI.encode_www_form_component(query)}",
      items: items(search_results)
    }
  end

  def item(status)
    {
      id: status["id"],
      url: status["url"],
      title: nil,
      content_html: status["content"],
      date_published: status["created_at"],
      authors: [
        {
          name: status["account"]["display_name"],
          url: status["account"]["url"],
          avatar: status["account"]["avatar"],
          _social: {
            username: status["account"]["username"]
          }
        }
      ]
    }
  end
end
