require "test_helper"

class RedditControllerTest < ActionDispatch::IntegrationTest
  # Reddit's application-only OAuth token response.
  TOKEN = FakeResponse.json({ "access_token" => "reddit-token", "expires_in" => 3600 })

  # A minimal subreddit listing: one image post and one self/text post. Kept
  # small and gfycat/oembed-free on purpose so rendering stays deterministic.
  # oauth.reddit.com returns the same Listing shape as the old .json scrape.
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
    with_reddit("oauth.reddit.com/r/test" => FakeResponse.json(LISTING)) do
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
    with_reddit("oauth.reddit.com/r/test" => FakeResponse.json(LISTING)) do
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

  test "authenticates with client_credentials then fetches via the OAuth API with no proxy" do
    calls = []
    HttpRequest.define_singleton_method(:new) do |url, **opts|
      fake = Object.new
      fake.define_singleton_method(:get) do
        calls << { url: url.to_s, opts: opts, method: :get }
        FakeResponse.json(LISTING)
      end
      fake.define_singleton_method(:post) do |body = nil|
        calls << { url: url.to_s, opts: opts, method: :post, body: body }
        FakeResponse.json({ "access_token" => "reddit-token", "expires_in" => 3600 })
      end
      fake
    end

    begin
      stub_credentials(reddit_client_id!: "id", reddit_client_secret!: "secret") do
        get "/reddit/test"
      end
    ensure
      HttpRequest.singleton_class.send(:remove_method, :new)
    end

    token_call = calls.find { |c| c[:method] == :post }
    listing_call = calls.find { |c| c[:method] == :get }

    # Token request: application-only grant with the client id/secret as HTTP Basic auth.
    assert_includes token_call[:url], "www.reddit.com/api/v1/access_token"
    assert_equal "grant_type=client_credentials", token_call[:body]
    assert_equal "Basic #{[ "id:secret" ].pack("m0")}", token_call.dig(:opts, :headers, "Authorization")

    # Listing request: OAuth host, bearer token, and no proxy (OAuth replaces the IP workaround).
    assert_equal "https://oauth.reddit.com/r/test", listing_call[:url]
    assert_equal "Bearer reddit-token", listing_call.dig(:opts, :headers, "Authorization")
    assert_nil listing_call.dig(:opts, :proxy)
  end

  test "raises when the OAuth token request fails" do
    error = assert_raises(RuntimeError) do
      stub_credentials(reddit_client_id!: "id", reddit_client_secret!: "secret") do
        stub_http("access_token" => FakeResponse.new("401", "forbidden")) do
          get "/reddit/test"
        end
      end
    end

    assert_match(/authentication failed/i, error.message)
  end

  # End-to-end against a real r/aww capture. This is the only test that exercises
  # the content view's video and gallery branches with genuine Reddit payloads
  # (entity-escaped urls, crosspost metadata, etc.).
  test "renders real video and gallery posts from a captured listing" do
    listing = JSON.parse(File.read(Rails.root.join("test/support/subreddit.json")))

    with_reddit("oauth.reddit.com/r/aww" => FakeResponse.json(listing)) do
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

  private

  # Stubs the Reddit credentials and both HTTP calls (token + listing). The
  # token endpoint is matched by the "access_token" url fragment.
  def with_reddit(responses, &block)
    stub_credentials(reddit_client_id!: "id", reddit_client_secret!: "secret") do
      stub_http({ "access_token" => TOKEN }.merge(responses), &block)
    end
  end
end
