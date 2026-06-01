require "test_helper"

class RedditControllerTest < ActionDispatch::IntegrationTest
  # A minimal subreddit listing: one image post and one self/text post. Kept
  # small and gfycat/oembed-free on purpose so rendering stays deterministic.
  LISTING = {
    "data" => {
      "children" => [
        { "kind" => "t3", "data" => {
          "id" => "abc",
          "permalink" => "/r/test/comments/abc/post_one/",
          "title" => "Post one",
          "author" => "alice",
          "created_utc" => 1_700_000_000,
          "post_hint" => "image",
          "url" => "https://i.redd.it/example.jpg"
        } },
        { "kind" => "t3", "data" => {
          "id" => "def",
          "permalink" => "/r/test/comments/def/post_two/",
          "title" => "Post two",
          "author" => "bob",
          "created_utc" => 1_700_000_100,
          "post_hint" => "self",
          "url" => "https://www.reddit.com/r/test/comments/def/post_two/",
          "selftext" => "hello"
        } }
      ]
    }
  }.freeze

  test "returns a JSON Feed for the subreddit" do
    stub_http("old.reddit.com/r/test.json" => FakeResponse.json(LISTING)) do
      get "/reddit/test"
    end

    assert_response :success

    feed = response.parsed_body
    assert_equal "https://jsonfeed.org/version/1.1", feed["version"]
    assert_equal "test", feed["title"]
    assert_equal "https://www.reddit.com/r/test", feed["feed_url"]
    assert_equal 2, feed["items"].size
  end

  test "maps a post into a feed item with rendered content" do
    stub_http("old.reddit.com/r/test.json" => FakeResponse.json(LISTING)) do
      get "/reddit/test"
    end

    item = response.parsed_body["items"].first
    assert_equal "abc", item["id"]
    assert_equal "https://old.reddit.com/r/test/comments/abc/post_one/", item["url"]
    assert_equal "Post one", item["title"]
    assert_includes item["content_html"], "https://i.redd.it/example.jpg"
    assert_equal "alice", item["authors"].first["name"]
    assert_equal "https://old.reddit.com/user/alice", item["authors"].first["url"]
  end

  test "requests the subreddit from the listing endpoint through the proxy" do
    requested = nil
    options = nil
    HttpRequest.define_singleton_method(:new) do |url, **opts|
      requested = url.to_s
      options = opts
      FakeHttpRequest.new(url, "test.json" => FakeResponse.json(LISTING))
    end

    begin
      get "/reddit/test"
    ensure
      HttpRequest.singleton_class.send(:remove_method, :new)
    end

    assert_equal "https://old.reddit.com/r/test.json", requested
    # Reddit blocks the server's IP, so the listing must be fetched via the proxy.
    assert_equal true, options[:proxy]
  end

  # End-to-end against a real old.reddit.com/r/aww.json capture. This is the
  # only test that exercises the content view's video and gallery branches with
  # genuine Reddit payloads (entity-escaped urls, crosspost metadata, etc.).
  test "renders real video and gallery posts from a captured listing" do
    listing = JSON.parse(File.read(Rails.root.join("test/support/subreddit.json")))

    stub_http("old.reddit.com/r/aww.json" => FakeResponse.json(listing)) do
      get "/reddit/aww"
    end

    assert_response :success
    items = response.parsed_body["items"]
    assert_equal 26, items.size

    video = items.find { |item| item["id"] == "1fft2lf" }
    assert_includes video["content_html"], "<video"
    assert_includes video["content_html"], "v.redd.it"
    refute_includes video["content_html"], "&amp;amp;", "video urls should be unescaped, not double-escaped"

    gallery = items.find { |item| item["id"] == "1fg1i35" }
    assert_equal 3, gallery["content_html"].scan("<img").size
  end
end
