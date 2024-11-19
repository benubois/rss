require "net/http"

class HttpRequest
  def initialize(url, proxy: false, headers: {})
    @url = url
    @proxy = proxy
    @headers = headers
  end

  def get
    make_request(Net::HTTP::Get)
  end

  def post(body)
    make_request(Net::HTTP::Post) do |request|
      request.body = body
    end
  end

  private

  def headers
    Hash.new.tap do |hash|
      hash["User-Agent"] = Rails.application.credentials.user_agent if Rails.application.credentials.user_agent
    end.merge(@headers)
  end

  def make_request(request_class)
    request = request_class.new(@url)

    headers.each do |name, value|
      request[name] = value
    end

    yield request if block_given?

    http_client.start(@url.hostname, @url.port, use_ssl: @url.scheme == "https") do |http|
      http.request(request)
    end
  end

  def http_client
    if @proxy
      proxy = URI.parse(Rails.application.credentials.proxy_url!)
      Net::HTTP::Proxy(proxy.host, proxy.port, proxy.user, proxy.password)
    else
      Net::HTTP
    end
  end
end
