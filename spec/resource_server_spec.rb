require 'helper'
describe LygneoClient::ResourceServer do
  include LygneoClient
  before do
    @host = "lygneop.od"
    @self_url = "chubbi.es"
    @time = Time.now
    Time.stub(:now).and_return(@time)

    LygneoClient.private_key_path = File.dirname(__FILE__) + "/chubbies.private.pem"
  end

  describe '.register' do
    it 'posts to the token endpoint' do
      response = mock()
      resp_str = {:client_id => "aofosdjfg", :client_secret => "aosfjosdigh"}.to_json.to_s
      response.stub!(:body).and_return(resp_str)
      response.stub!(:success?).and_return(true)

      body = {:a => 'b'}
      LygneoClient::ResourceServer.any_instance.should_receive(:build_register_body).and_return(body)

      conn = mock()
      conn.should_receive(:post).
        with("https://#{@host}:443/oauth/token", body).
        and_return(response)
      Faraday.stub(:default_connection).and_return(conn)

      LygneoClient::ResourceServer.register(@host)
    end

    it 'raises if the connection response is not acceptable' do
      conn = mock
      conn.stub_chain(:post, :success? => false)
      conn.stub_chain(:post, :body => "Error message from the pod")
      Faraday.stub(:default_connection).and_return(conn)


      proc {
        LygneoClient::ResourceServer.register(@host)
      }.should raise_error LygneoClient::RegistrationError
    end
  end

  context 'uris' do
      before do
        @res = LygneoClient::ResourceServer.new(:host => 'pod.pod')
      end
    describe '#full_host' do
      it 'returns the https url by default' do
        @res.full_host.scheme.should == "https"
      end

      it 'returns the http scheme if test mode is configured' do
        LygneoClient.config do |d|
          d.test_mode = true
        end
        @res.full_host.scheme.should == "http"
      end

      it 'includes the pod uri' do
        @res.full_host.host.should == "pod.pod"
      end
    end

    describe '#token_endpoint' do
      it 'retruns the default route' do
        @res.token_endpoint.should include(@res.full_host + "/oauth/token")
      end
    end

    describe '#api_route' do
      it 'retruns the default route' do
        @res.api_route.should include(@res.full_host + "/api/v0")
      end
    end
  end

  describe '#build_register_body' do
    before do
      @resource = LygneoClient::ResourceServer.new(:host => @host)
    end
    it 'sets the type' do
      @resource.build_register_body[:type].should == :client_associate
    end

    it 'returns base64 encoded signable string' do
      str = "asdfas"
      @resource.stub(:signable_string).and_return(str)
      @resource.build_register_body[:signed_string].should == Base64.encode64(str)
    end

    it 'returns base64 encoded signature' do
      str = "SIG"
      LygneoClient.stub(:sign).and_return(str)
      @resource.build_register_body[:signature].should == Base64.encode64(str)
    end
  end

  describe '#signable_string' do
    it 'returns a signable string' do
      pod = LygneoClient::ResourceServer.new(:host => @host)
      SecureRandom.stub!(:base64).and_return("nonce")
      signable_string = [LygneoClient.application_base_url, "https://#{@host}:443", @time.to_i, "nonce"].join(';')
      pod.signable_string.should == signable_string
    end
  end
end
