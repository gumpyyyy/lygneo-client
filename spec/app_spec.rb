require 'helper'

describe LygneoClient::App do
  include Rack::Test::Methods
  def app
    @app ||= LygneoClient::App
  end

  it "should respond to /" do
    get '/'
    last_response.should be_redirect
  end

  it 'redirects back with an error if post fails or params are incorrect' do
    get '/'
    last_response.headers['Location'].include?("lygneo-client-error").should be_true
  end

  it 'handles a lygneo id with spaces at the end' do
    LygneoClient::ResourceServer.should_receive(:where).with(:host => 'thepod.com')
    get '/', 'lygneo_id' => 'icopypasted@thepod.com '
  end

  it 'handles a lygneo id with no spaces' do
    LygneoClient::ResourceServer.should_receive(:where).with(:host => 'thepod.com')
    get '/', 'lygneo_id' => 'icopypasted@thepod.com'
  end
end
