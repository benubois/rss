require "net/http"

class RedditController < ApplicationController

  BASE_URL = "https://old.reddit.com"

  def subreddit
    search_results = perform_search
    render json: feed(search_results)
  end

  private

  def perform_search
    uri = URI("#{BASE_URL}/r/#{params[:subreddit]}.json")
    response = HttpRequest.new(uri, proxy: true).get
    JSON.parse(response.body)
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
