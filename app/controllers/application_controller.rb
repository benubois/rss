class ApplicationController < ActionController::Base
  # Read-only JSON feed endpoints (all routes are GET). Declared explicitly so
  # static analysis sees forgery protection is on.
  protect_from_forgery with: :exception

  before_action :set_cache_headers, if: -> { request.get? }

  private

  def set_cache_headers
    expires_in 4.hours, public: true
  end
end
