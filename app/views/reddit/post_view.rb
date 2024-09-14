module Reddit
  class PostView < ApplicationView
    def initialize(post:)
      @post = post
    end

    def template
      case @post.media_type
      when "image"
        render_image
      when "reddit_video"
        render_reddit_video
      when "imgur"
        render_imgur_video
      when "gfycat"
        render_gfycat_video
      when "oembed"
        render_oembed
      when "gallery"
        render_gallery
      end
    end

    private

    def render_image
      a(href: @post.media_url) do
        img(src: @post.media_url)
      end
    end

    def render_reddit_video
      video(poster: @post.poster) do
        source(src: @post.reddit_video.dig("hls_url"), type: "application/x-mpegURL")
        source(src: @post.reddit_video.dig("dash_url"), type: "application/dash+xml")
        source(src: @post.reddit_video.dig("fallback_url"), type: "video/mp4")
      end
    end

    def render_imgur_video
      video(poster: "#{@post.imgur_url}.jpg", preload: "auto", autoplay: "autoplay", muted: "muted", loop: "loop", "webkit-playsinline": "") do
        source(src: "#{@post.imgur_url}.mp4", type: "video/mp4")
      end
    end

    def render_gfycat_video
      video(poster: @post.gfycat_poster, preload: "auto", autoplay: "autoplay", muted: "muted", loop: "loop", playsinline: "") do
        source(src: @post.gfycat_url, type: "video/mp4")
      end
    end

    def render_oembed
      unsafe_raw @post.oembed
    end

    def render_gallery
      @post.gallery_urls.each do |url|
        a(href: url) do
          img(src: url)
        end
      end
    end
  end
end