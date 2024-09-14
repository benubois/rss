require "net/http"

class RedditController < ApplicationController

  def subreddit
    search_results = perform_search(params[:query])
    render json: feed(search_results, params[:query])
  end

  private

  def perform_search(query)
    # Load and parse the JSON file
    file = File.read(Rails.root.join('test', 'support', 'subreddit.json'))
    JSON.parse(file)
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

  def content
    <<~EOD
    <p>Helo?</p>

    EOD
  end
end
