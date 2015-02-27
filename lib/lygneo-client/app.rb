require 'addressable/uri'

module LygneoClient
  class App < Sinatra::Base

    # @return [OAuth2::Client] The connecting Lygneo installation's Client object.
    # @see #pod
    def client
      pod.client
    end

    # Find a pre-existing Lygneo server, or register with a new one.
    #
    # @note The Lygneo server is parsed from the domain in the given lygneo handle.
    # @return [ResourceServer]
    def pod
      @pod ||= lambda{
        host = lygneo_id.split('@')[1]
        ResourceServer.where(:host => host).first || ResourceServer.register(host)
      }.call
    end

    # Retreive the user's Lygneo id from the params hash.
    #
    # @return [String]
    def lygneo_id
      @lygneo_id ||= params['lygneo_id'].strip
    end

    def uid
      @uid ||= lygneo_id.split('@')[0]
    end

    # @return [String] The path to hit after retreiving an access token from a Lygneo server.
    def redirect_path
      '/auth/lygneo/callback'
    end

    # @return [String] The path to send the user after the OAuth2 dance is complete.
    def after_oauth_redirect_path
      '/'
    end

    # @option hash [String] :lygneo_id The connecting user's lygneo id
    # @return [ActiveRecord::Base] A created and persisted user account which an access token can be attached to.
    def create_account(hash)
      LygneoClient.account_class.send(LygneoClient.account_creation_method, hash)
    end

    # @return [String] The URL to hit after retreiving an access token from a Lygneo server.
    # @see #redirect_path
    def redirect_uri
      uri = Addressable::URI.parse(request.url)
      uri.path = redirect_path
      uri.query_values = {:lygneo_id => lygneo_id}
      uri.to_s
    end

    # @return [User] The current user stored in warden.
    def current_user
      request.env["warden"].user
    end

    def current_user=(user)
      request.env["warden"].set_user(user, :scope => :user, :store => true)
    end

    # @return [void]
    get '/' do

      # ensure faraday is configured
      LygneoClient.setup_faraday

      begin
        redirect client.authorize_url(client.auth_code.authorize_params.merge(
          :redirect_uri => redirect_uri,
          :scope => 'profile,AS_photo:post',
          :uid => uid
        ))
      rescue Exception => e
        redirect_url = back.to_s
        if defined?(Rails)
          flash_class = ActionDispatch::Flash
          flash = request.env["action_dispatch.request.flash_hash"] ||= flash_class::FlashHash.new
          flash.alert = e.message
        else
          redirect_url << "?lygneo-client-error=#{URI.escape(e.message[0..800])}"
        end
        redirect redirect_url
      end
    end

    # @return [void]
    get '/callback' do
      if !params["error"]

        access_token = client.auth_code.get_token(params[:code],
                       pod.build_register_body.merge(:redirect_uri => redirect_uri))

        user_json = JSON.parse(access_token.get('/api/v0/me').body)

        url = Addressable::URI.parse(client.auth_code.authorize_url).normalized_host
        if port = Addressable::URI.parse(client.auth_code.authorize_url).normalized_port
          url += ":#{port}"
        end

        self.current_user ||= create_account(:lygneo_id => user_json['uid'] + "@" + url)

        if at = current_user.access_token
          at.destroy
          current_user.access_token = nil
        end

        current_user.create_access_token(
          :uid => user_json["uid"],
          :resource_server_id => pod.id,
          :access_token => access_token.token,
          :refresh_token => access_token.refresh_token,
          :expires_at => access_token.expires_at
        )

      elsif params["error"] == "invalid_client"
        ResourceServer.register(lygneo_id.split('@')[1])
        redirect "/?lygneo_id=#{lygneo_id}"
      end

      redirect after_oauth_redirect_path
    end

    # Destroy the current user's access token and redirect.
    #
    # @return [void]
    delete '/' do
      current_user.access_token.destroy
      redirect after_oauth_redirect_path
    end

  end
end
