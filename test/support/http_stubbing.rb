# Test support for stubbing the app's HTTP layer without hitting the network.
#
# The controllers talk to external services exclusively through
# HttpRequest.new(...).get / .post. These helpers replace HttpRequest.new with
# a fake that returns canned responses, matched by a substring of the request
# URL, so controller tests stay deterministic and offline.
#
# Stubbing is done by hand (define a temporary singleton method, restore in an
# ensure) because the bundled minitest build ships without Minitest::Mock.

# Minimal stand-in for the Net::HTTPResponse objects the controllers consume.
# They only ever read #code (a string like "200") and #body.
FakeResponse = Struct.new(:code, :body) do
  def self.json(body, code: "200")
    new(code, body.is_a?(String) ? body : body.to_json)
  end
end

# Returned by the stubbed HttpRequest.new. Picks a response by matching a
# substring against the request URL, so a single stub can serve the several
# requests a controller makes (e.g. Bluesky auth + feed fetch).
class FakeHttpRequest
  def initialize(url, responses)
    @url = url.to_s
    @responses = responses
  end

  def get
    response_for
  end

  def post(_body = nil)
    response_for
  end

  private

  def response_for
    _match, response = @responses.find { |fragment, _| @url.include?(fragment) }
    raise "No stubbed HTTP response matches #{@url.inspect} (have: #{@responses.keys.inspect})" unless response

    response
  end
end

module HttpStubbing
  # responses: { "url-fragment" => FakeResponse, ... }
  def stub_http(responses)
    HttpRequest.define_singleton_method(:new) do |url, **_opts|
      FakeHttpRequest.new(url, responses)
    end
    yield
  ensure
    HttpRequest.singleton_class.send(:remove_method, :new)
  end

  # Stub credential reads so tests don't depend on the master key. Accepts the
  # accessor with or without the bang (Bluesky uses :foo, Mastodon :foo!).
  def stub_credentials(values)
    creds = Rails.application.credentials
    values.each { |name, value| creds.define_singleton_method(name) { value } }
    yield
  ensure
    values.each_key { |name| creds.singleton_class.send(:remove_method, name) }
  end
end
