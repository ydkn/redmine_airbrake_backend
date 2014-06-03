require 'redmine_airbrake_backend/engine'

module RedmineAirbrakeBackend
  def self.directory
    File.expand_path(File.join(File.dirname(__FILE__), '..'))
  end
end
