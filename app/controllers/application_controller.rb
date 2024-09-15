class ApplicationController < ActionController::Base
  before_action :set_cache_headers, if: -> { request.get? }

  private

  def set_cache_headers
    expires_in 4.hours, public: true
  end
end
