require 'lygneo-client'
require 'rails'
module LygneoClient

  # Binds rake tasks into corresponding Rails application.
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join( File.join( File.dirname(__FILE__) , "..","..", "lib","tasks","lygneo-client.rake" ) )
    end
  end
end
