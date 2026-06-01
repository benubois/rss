require "test_helper"

class BlueskyControllerTest < ActionDispatch::IntegrationTest
  AUTH = FakeResponse.json({ "accessJwt" => "jwt-token" })

  # A single post as returned by app.bsky.feed.getAuthorFeed / searchPosts.
  POST = {
    "uri" => "at://did:plc:abc/app.bsky.feed.post/xyz123",
    "author" => {
      "handle" => "alice.bsky.social",
      "displayName" => "Alice",
      "avatar" => "https://example.com/avatar.jpg"
    },
    "record" => {
      "text" => "Hello world\n\nSecond paragraph",
      "createdAt" => "2024-01-01T00:00:00Z"
    },
    "embed" => {
      "images" => [
        { "fullsize" => "https://example.com/image.jpg", "alt" => "a cat",
          "aspectRatio" => { "width" => 100, "height" => 200 } }
      ]
    }
  }.freeze

  test "user action returns a JSON Feed for the author feed" do
    feed_response = FakeResponse.json({ "feed" => [ { "post" => POST } ] })

    with_bluesky("getAuthorFeed" => feed_response) do
      get "/bluesky/user/alice.bsky.social"
    end

    assert_response :success

    feed = response.parsed_body
    assert_equal "https://jsonfeed.org/version/1", feed["version"]
    assert_equal "@alice.bsky.social", feed["title"]
    assert_equal 1, feed["items"].size

    item = feed["items"].first
    assert_equal "at://did:plc:abc/app.bsky.feed.post/xyz123", item["id"]
    assert_equal "https://bsky.app/profile/alice.bsky.social/post/xyz123", item["url"]
    assert_includes item["content_html"], "Hello world"
    assert_includes item["content_html"], "https://example.com/image.jpg"
    assert_equal "Alice", item["authors"].first["name"]
    assert_equal "alice.bsky.social", item["authors"].first.dig("_social", "username")
  end

  test "search action returns a JSON Feed for matching posts" do
    search_response = FakeResponse.json({ "posts" => [ POST ] })

    with_bluesky("searchPosts" => search_response) do
      get "/bluesky/search", params: { query: "cats" }
    end

    assert_response :success

    feed = response.parsed_body
    assert_equal "@cats", feed["title"]
    assert_equal 1, feed["items"].size
    assert_equal "at://did:plc:abc/app.bsky.feed.post/xyz123", feed["items"].first["id"]
  end

  test "user action renders 401 when the feed request is unauthorized" do
    with_bluesky("getAuthorFeed" => FakeResponse.new("401", "")) do
      get "/bluesky/user/alice.bsky.social"
    end

    assert_response :unauthorized
    assert_equal "Unauthorized", response.parsed_body["error"]
  end

  private

  def with_bluesky(responses, &block)
    stub_credentials(bluesky_handle: "handle", bluesky_access_token: "secret") do
      stub_http({ "createSession" => AUTH }.merge(responses), &block)
    end
  end
end
