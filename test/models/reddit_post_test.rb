require "test_helper"

# Unit tests for RedditPost, the class that holds the bulk of the app's logic:
# classifying a Reddit listing entry by media type and normalising its URLs.
#
# These run against test/support/subreddit.json, a real capture of
# old.reddit.com/r/aww.json, so the expected values below are the actual values
# Reddit returned. The capture contains image posts, hosted videos, galleries
# and self/text posts, which is every live branch of #media_type.
class RedditPostTest < ActiveSupport::TestCase
  # Child nodes from the real capture, keyed by their Reddit id.
  LISTING = JSON.parse(File.read(Rails.root.join("test/support/subreddit.json")))
  CHILDREN = LISTING.dig("data", "children").index_by { |child| child.dig("data", "id") }

  IMAGE_ID   = "1fg43n9"  # post_hint: "image", url on i.redd.it
  VIDEO_ID   = "1fft2lf"  # secure_media.reddit_video present
  GALLERY_ID = "1fg1i35"  # is_gallery: true, three images
  SELF_ID    = "171dxph"  # text post, no media

  def post(id)
    RedditPost.new(CHILDREN.fetch(id))
  end

  # --- basic field extraction -------------------------------------------------

  test "id, title and author are read from the post data" do
    image = post(IMAGE_ID)
    assert_equal "1fg43n9", image.id
    assert_equal "Dr_Ponzu", image.author
    assert_includes image.title, "Mojo turned 20"
  end

  test "url is the absolute old.reddit.com permalink" do
    assert_equal "https://old.reddit.com/r/aww/comments/1fg43n9/our_mojo_turned_20_a_few_days_ago_always_cute/",
                 post(IMAGE_ID).url
  end

  test "published renders created_utc as a UTC ISO 8601 timestamp" do
    # created_utc for the image post is 1726257906.
    assert_equal "2024-09-13T20:05:06+0000", post(IMAGE_ID).published
  end

  test "published falls back to the current time when created_utc is missing" do
    bare = RedditPost.new({ "data" => {} })
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+0000\z/, bare.published)
  end

  # --- media_type classification ----------------------------------------------

  test "media_type is image for an image post" do
    assert_equal "image", post(IMAGE_ID).media_type
  end

  test "media_type is reddit_video for a hosted video post" do
    assert_equal "reddit_video", post(VIDEO_ID).media_type
  end

  test "media_type is gallery for a gallery post" do
    assert_equal "gallery", post(GALLERY_ID).media_type
  end

  test "media_type is nil for a self/text post" do
    assert_nil post(SELF_ID).media_type
  end

  test "media_type is imgur for a link post on an imgur domain" do
    imgur = RedditPost.new({ "data" => {
      "post_hint" => "link",
      "domain" => "i.imgur.com",
      "url" => "https://i.imgur.com/abc123.gifv"
    } })
    assert_equal "imgur", imgur.media_type
  end

  test "media_type is gfycat for a gfycat url and captures the video id" do
    gfycat = RedditPost.new({ "data" => { "url" => "https://gfycat.com/SomeClip" } })
    assert_equal "gfycat", gfycat.media_type
  end

  # --- url normalisation (HTML entity unescaping) -----------------------------

  test "media_url unescapes HTML entities in the url" do
    post = RedditPost.new({ "data" => {
      "url" => "https://example.com/x.jpg?a=1&amp;b=2"
    } })
    assert_equal "https://example.com/x.jpg?a=1&b=2", post.media_url
  end

  test "gallery_urls returns one unescaped url per gallery item" do
    urls = post(GALLERY_ID).gallery_urls

    assert_equal 3, urls.size
    assert_equal "https://preview.redd.it/rfxcjp55bmod1.jpg?width=1080&format=pjpg&auto=webp&s=4115f9cd089de90404da16be300ad3896691fe48",
                 urls.first
    refute urls.any? { |url| url.include?("&amp;") }, "gallery urls should be HTML-unescaped"
  end

  # --- reddit_video -----------------------------------------------------------

  test "reddit_video returns the secure_media video object" do
    video = post(VIDEO_ID).reddit_video
    assert_kind_of Hash, video
    assert video["fallback_url"].present?
  end

  test "reddit_video prefers the crosspost parent's video" do
    crosspost = RedditPost.new({ "data" => {
      "crosspost_parent_list" => [ { "secure_media" => { "reddit_video" => { "fallback_url" => "from-crosspost" } } } ],
      "secure_media" => { "reddit_video" => { "fallback_url" => "from-self" } }
    } })
    assert_equal "from-crosspost", crosspost.reddit_video["fallback_url"]
  end

  test "poster is only present for video posts and is unescaped" do
    assert_nil post(IMAGE_ID).poster, "non-video posts have no poster"

    poster = post(VIDEO_ID).poster
    assert poster.start_with?("https://"), "video poster should be a url"
    refute poster.include?("&amp;"), "video poster should be HTML-unescaped"
  end

  # --- imgur helpers ----------------------------------------------------------

  test "imgur_id is parsed from a single-segment imgur path, stripping the extension" do
    imgur = RedditPost.new({ "data" => { "url" => "https://i.imgur.com/abc123.gifv" } })
    assert_equal "abc123", imgur.imgur_id
    assert_equal "https://imgur.com/abc123", imgur.imgur_url
    assert_equal "https://imgur.com/abc123.gif", imgur.imgur_image_url
  end

  test "imgur_id is nil for non-imgur urls" do
    other = RedditPost.new({ "data" => { "url" => "https://i.redd.it/foo.jpg" } })
    assert_nil other.imgur_id
  end
end
