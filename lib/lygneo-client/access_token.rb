module LygneoClient
  class AccessToken < ActiveRecord::Base
    belongs_to :user
    belongs_to :resource_server

    # Fetches the current or generates a new access token.
    #
    # @return [OAuth2::AccessToken]
    def token
      @token ||= OAuth2::AccessToken.new(
        resource_server.client,
        access_token,
        :refresh_token => refresh_token,
        :expires_in => expires_in,
        :adapter => LygneoClient.which_faraday_adapter?
      )
    end

    # @return [Integer] Unix time until token experation.
    def expires_in
      Time.at(expires_at - Time.now)
    end
  end
end
