require 'helper'
describe LygneoClient do

  context 'application private key' do

    before do
      pub_key_path = File.dirname(__FILE__) + "/chubbies.public.pem"
      private_key_path = File.dirname(__FILE__) + "/chubbies.private.pem"

      LygneoClient.config do |p|
        p.public_key_path = pub_key_path
        p.private_key_path = private_key_path
      end

      @priv_key_fixture = File.read(private_key_path)
      @public_key_fixture = File.read(pub_key_path)
    end

    it 'returns an OpenSSL key' do
      LygneoClient.private_key.class.should == OpenSSL::PKey::RSA
    end

    it 'reads and returns the private key' do
      LygneoClient.private_key.to_s.should == @priv_key_fixture
    end

    it 'reads and returns the public key' do
      LygneoClient.public_key.to_s.should == @public_key_fixture
    end

    it 'allows for custom path' do
      path = "/path/to/key.pem"
      LygneoClient.private_key_path = path
      File.should_receive(:read).with(path).and_return(@priv_key_fixture)
      LygneoClient.private_key
    end

    it 'memoizes the private key reading' do
      File.should_receive(:read).with(LygneoClient.private_key_path).once.and_return(@priv_key_fixture)
      LygneoClient.private_key
      LygneoClient.private_key
    end

    describe '.sign' do
      it 'signs plaintext' do
        plaintext = "cats"
        LygneoClient.private_key.should_receive(:sign).with( OpenSSL::Digest::SHA256.new, plaintext)
        LygneoClient.sign(plaintext)
      end
    end
  end

  describe ".config" do
    it 'runs the block passed to it' do
      LygneoClient.config do |d|
        d.private_key_path = "AWESOME"
        d.public_key_path = "SAUCE"
      end

      LygneoClient.private_key_path.should == "AWESOME"
      LygneoClient.public_key_path.should == "SAUCE"
    end

    it 'sets smart defaults' do
      LygneoClient.should_receive(:initialize_instance_variables)
      LygneoClient.config do |d|
      end
    end

    it 'sets the manifest fields' do
      LygneoClient.config do |d|
        d.manifest_field(:name, "Chubbies")
        d.manifest_field(:description, "The best way to chub.")
        d.manifest_field(:icon_url, "#")

        d.manifest_field(:permissions_overview, "Chubbi.es wants to post photos to your stream.")
      end

      LygneoClient.manifest_fields[:name].should == "Chubbies"
      LygneoClient.manifest_fields[:description].should == "The best way to chub."
      LygneoClient.manifest_fields[:icon_url].should == "#"
      LygneoClient.manifest_fields[:permissions_overview].should == "Chubbi.es wants to post photos to your stream."
    end


    it 'sets the permission requests and descriptions' do
      LygneoClient.config do |d|
       d.permission(:profile, :read, "Chubbi.es wants to view your profile so that it can show it to other users.")
       d.permission(:photos, :write, "Chubbi.es wants to write to your photos to share your findings with your contacts.")
      end

      pr = LygneoClient.permissions[:profile]
      pr[:access].should == LygneoClient::READ
      pr[:type].should == LygneoClient::PROFILE
      pr[:description].should == "Chubbi.es wants to view your profile so that it can show it to other users."

      pr = LygneoClient.permissions[:photos]
      pr[:access].should == LygneoClient::WRITE
      pr[:type].should == LygneoClient::PHOTOS
      pr[:description].should == "Chubbi.es wants to write to your photos to share your findings with your contacts."
    end

    it 'sets account_class and account_creation_method' do
      LygneoClient.account_class.should == nil
      LygneoClient.account_creation_method.should == :find_or_create_with_lygneo

      LygneoClient.config do |d|
        d.account_class = URI
        d.account_creation_method = :parse
      end

      LygneoClient.account_class.should == URI
      LygneoClient.account_creation_method.should == :parse
    end

    context "manifest checking" do
      before do
        LygneoClient.stub(:initialize_instance_variables)
        LygneoClient.stub(:write_manifest)
        @rails_mock = mock
        @rails_mock.stub(:env).and_return("production")
      end

      after do
        begin
          Object.send(:remove_const, :Rails)
        rescue NameError
        end
      end

      it 'does not check validity if Rails is udefined' do
        LygneoClient.should_not_receive(:verify_manifest)
        LygneoClient.config
      end
      
      it 'checks the validity if Rails is defined' do
        ::Rails = @rails_mock

        LygneoClient.should_receive(:verify_manifest).and_return(true)
        LygneoClient.config
      end

      it 'does not check validity if test mode' do
        ::Rails = @rails_mock

        LygneoClient.should_not_receive(:verify_manifest)
        LygneoClient.instance_variable_set(:@test_mode, true)
        LygneoClient.config
      end
      
      context 'does not verify' do
        before do
          @original_stderr = $stderr
          $stderr = StringIO.new
        end
        after do
          $stderr = @original_stderr
        end

        it "exits the manifest if it's not the same" do
          ::Rails = @rails_mock

          LygneoClient.stub(:verify_manifest).and_return(false)

          expect {
            LygneoClient.config
          }.should raise_error SystemExit

          $stderr.rewind
          $stderr.string.chomp.should_not be_blank
        end

      end
    end
  end


  describe 'setup_faraday' do
    it 'uses net:http if not in a reactor and 1.9.2' do
      LygneoClient.setup_faraday

      conn = Faraday.default_connection
      conn.builder.handlers.should_not include(Faraday::Adapter::EMSynchrony)
    end

    it 'uses JSON encode request' do
      LygneoClient.setup_faraday

      conn = Faraday.default_connection
      conn.builder.handlers.should include(Faraday::Request::JSON)
    end

    it 'uses net:http if not in a reactor and 1.9.2' do
      if defined?(EM)
        EM.stub(:reactor_running?).and_return(true)
      end
      
      LygneoClient.setup_faraday

      conn = Faraday.default_connection
      if defined?(EM)
        conn.builder.handlers.should include(Faraday::Adapter::EMSynchrony)
      else
        conn.builder.handlers.should include Faraday::Adapter::NetHttp
      end
    end
  end

  describe '.application_base_url' do
    it 'works with localhost' do
      LygneoClient.config do |d|
        d.application_base_url = "localhost:6924"
      end
      LygneoClient.application_base_url.to_s.should == "https://localhost:6924/"
    end

    it 'normalizes application_base_url' do
      LygneoClient.config do |d|
        d.application_base_url= "google.com"
      end

      LygneoClient.application_base_url.to_s.should == "https://google.com:443/"
    end
  end

  describe ".scheme" do
    it 'sets the https app url by default' do
      LygneoClient.scheme.should == 'https'
    end

    it 'sets the http app url in test mode' do
      LygneoClient.config do |d|
        d.test_mode = true
      end
      LygneoClient.scheme.should == 'http'
    end
  end

  context "manifest" do
    before do
      pub_key_path = File.dirname(__FILE__) + "/chubbies.public.pem"
      private_key_path = File.dirname(__FILE__) + "/chubbies.private.pem"

      LygneoClient.config do |d|
        d.public_key_path = pub_key_path
        d.private_key_path = private_key_path
        d.application_base_url = "http://localhost:4000/"

        d.manifest_field(:name, "Chubbies")
        d.manifest_field(:description, "The best way to chub.")
        d.manifest_field(:icon_url, "#")

        d.manifest_field(:permissions_overview, "Chubbi.es wants to post photos to your stream.")

        d.permission(:profile, :read, "Chubbi.es wants to view your profile so that it can show it to other users.")
        d.permission(:photos, :write, "Chubbi.es wants to write to your photos to share your findings with your contacts.")
      end
    end

    describe ".generate_manifest" do
      it 'puts application_base_url into the manifest' do
        LygneoClient.generate_manifest[:application_base_url].should_not be_blank
      end
    end

    describe ".verify_manifest" do
      it "returns true if the json in the file is the same" do
        LygneoClient.stub(:read_manifest).and_return(LygneoClient.package_manifest)
        LygneoClient.verify_manifest.should be_true
      end

      it "returns false if the manifest is different" do
        LygneoClient.stub(:read_manifest).and_return(JSON.generate({:a => "b"}))
        LygneoClient.verify_manifest.should be_false
      end
    end

    describe ".package_manifest" do
      it 'puts the public key in the manifest package' do
        JSON.parse(LygneoClient.package_manifest)['public_key'].should_not be_blank
      end

      context "JWT" do
        before do
          @packaged_manifest_jwt = JSON.parse(LygneoClient.package_manifest)['jwt']
          @pub_key = OpenSSL::PKey::RSA.new(LygneoClient.public_key)
        end

        it 'is present' do
          @packaged_manifest_jwt.should_not be_blank
        end

        it 'has all manifest fields' do
          JWT.decode(@packaged_manifest_jwt, @pub_key).symbolize_keys.should include(LygneoClient.manifest_fields)
        end

        it 'has all permission fields' do
          jwt_permissions = JWT.decode(@packaged_manifest_jwt, @pub_key)["permissions"].symbolize_keys
          jwt_permissions.keys.each do |key|
            jwt_permissions[key].symbolize_keys.should == LygneoClient.permissions[key]
          end
        end
      end
    end
  end
end
