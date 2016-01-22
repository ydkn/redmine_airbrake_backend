require 'redmine_airbrake_backend/engine'

module RedmineAirbrakeBackend
  def self.directory
    File.expand_path(File.join(File.dirname(__FILE__), '..'))
  end

  def self.filter_hex_values(value)
    value.gsub(/0x[0-9a-f]+/, '')
  end
end
