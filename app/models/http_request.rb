class HttpRequest
  def initialize(url, proxy: false, headers: {})
    @url = url
    @proxy = proxy
    @headers = headers
  end

  def get
    http = HTTP
      .headers(headers)
      .follow(max_hops: 4)
      .timeout(connect: 5, write: 5, read: 30)
      .use(:auto_inflate)
    if @proxy
      url = URI.parse(Rails.application.credentials.proxy_url!)
      http.via(url.host, url.port, url.user, url.password)
    end
    http.get(@url)
  end

  def headers
    Hash.new.tap do |hash|
      hash[:user_agent]        = Rails.application.credentials.user_agent if Rails.application.credentials.user_agent
      hash[:accept_encoding]   = "gzip, deflate" if @auto_inflate
    end.merge(@headers)
  end

end