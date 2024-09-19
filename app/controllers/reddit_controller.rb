require "net/http"

class RedditController < ApplicationController

  BASE_URL = "https://old.reddit.com"
  def subreddit
    search_results = perform_search(params[:query])
    render json: feed(search_results, params[:query])
  end

  private

  def perform_search(query)
    uri = URI("#{BASE_URL}/r/#{params[:subreddit]}.json")
    uri.query = URI.encode_www_form({ q: query, limit: 20 })
    response = HttpRequest.new(uri.to_s, proxy: true).get
    response.parse
  end

  def items(search_results)
    items = []

    search_results["data"]["children"].each do |post|
      items << item(RedditPost.new(post))
    end

    items
  end

  def feed(search_results, query)
    {
      version: "https://jsonfeed.org/version/1.1",
      title: "Reddit r/#{params[:subreddit]}",
      home_page_url: "https://www.reddit.com",
      feed_url: "https://www.reddit.com/search?q=#{URI.encode_www_form_component(query)}",
      items: items(search_results)
    }
  end

  def item(post)
    {
      id: post.id,
      url: post.url,
      title: post.title,
      content_html: ApplicationController.render("reddit/content", locals: {post: post}, layout: nil),
      date_published: post.published,
      authors: [
        {
          name: post.author,
          url: "https://old.reddit.com/user/#{post.author}",
        }
      ]
    }
  end
end
