require "net/http"

class HttpRequest
  def initialize(url, proxy: false, headers: {})
    @url = url
    @proxy = proxy
    @headers = headers
  end

  def get
    request = Net::HTTP::Get.new(@url)

    headers.each do |name, value|
      request[name] = value
    end

    base = if @proxy
      proxy = URI.parse(Rails.application.credentials.proxy_url!)
      Net::HTTP::Proxy(proxy.host, proxy.port, proxy.user, proxy.password)
    else
      Net::HTTP
    end

    base.start(@url.hostname, @url.port, use_ssl: @url.scheme == "https") do |http|
      http.request(request)
    end
  end

  def headers
    Hash.new.tap do |hash|
      hash["User-Agent"] = Rails.application.credentials.user_agent if Rails.application.credentials.user_agent
    end.merge(@headers)
  end
end
