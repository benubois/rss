require "test_helper"

class MastodonControllerTest < ActionDispatch::IntegrationTest
  STATUS = {
    "id" => "111",
    "url" => "https://mastodon.social/@alice/111",
    "content" => "<p>hello cats</p>",
    "created_at" => "2024-01-01T00:00:00Z",
    "account" => {
      "display_name" => "Alice",
      "url" => "https://mastodon.social/@alice",
      "avatar" => "https://example.com/avatar.png",
      "username" => "alice"
    }
  }.freeze

  test "returns a JSON Feed of search results" do
    stub_search({ "statuses" => [ STATUS ] }) do
      get "/mastodon/search", params: { query: "cats" }
    end

    assert_response :success

    feed = response.parsed_body
    assert_equal "https://jsonfeed.org/version/1.1", feed["version"]
    assert_equal "Mastodon cats", feed["title"]
    assert_equal 1, feed["items"].size

    item = feed["items"].first
    assert_equal "111", item["id"]
    assert_equal "https://mastodon.social/@alice/111", item["url"]
    assert_equal "<p>hello cats</p>", item["content_html"]
    assert_equal "Alice", item["authors"].first["name"]
    assert_equal "alice", item["authors"].first.dig("_social", "username")
  end

  test "returns an empty item list when there are no statuses" do
    stub_search({}) do
      get "/mastodon/search", params: { query: "nothing" }
    end

    assert_response :success
    assert_equal [], response.parsed_body["items"]
  end

  private

  def stub_search(body, &block)
    stub_credentials(mastodon_access_token!: "test-token") do
      stub_http({ "/api/v2/search" => FakeResponse.json(body) }, &block)
    end
  end
end
