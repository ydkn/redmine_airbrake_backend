# Redmine Airbrake Backend

This plugin provides the necessary API to use Redmine as an Airbrake backend.

## Installation

Apply this [patch](http://www.redmine.org/issues/14402) to Redmine.

Add this line to your Redmine Gemfile:

    gem 'redmine_airbrake_backend'

And then execute:

    $ bundle install
    $ rake redmine:plugins:migrate

## Integration

1. Create the following custom fields for issues:
  * Airbrake Hash (String)
  * Number of Occurrences (Integer) (optional)
2. Configure the plugin to use these 2 custom fields (Administration -> Plugins -> Configure)
3. Enable the project module (Airbrake) in your project settings
4. Configure additionale defaults under the settings tab (Airbrake)

## Client configuration

For a Rails application, just setup the [Airbrake notifier](https://github.com/airbrake/airbrake) as usual, then modify `config/initializers/airbrake.rb` according to your needs using this template:

```ruby
Airbrake.configure do |config|
  config.api_key = {
      project: 'redmine_project_identifier',    # the identifier you specified for your project in Redmine
      api_key: 'redmine_api_key',               # the api key for a user which has permission to create issues in the project specified in the previous step
      tracker: 'Bug',                           # the name or id of your desired tracker (optional if default is configured)
      category: 'Development',                  # the name or id of a ticket category, optional
      priority: 5                               # the name or id of the priority for new tickets, optional.
      assignee: 'admin',                        # the login or id of a user the ticket should get assigned to by default, optional
    }.to_json
  config.host = 'my_redmine_host.com'           # the hostname your Redmine runs at
  config.port = 443                             # the port your Redmine runs at
  config.secure = true                          # sends data to your server using SSL, optional
end
```

## Notes

Based on https://github.com/milgner/redmine_airbrake_server

## Code Status

* [![Gem Version](https://badge.fury.io/rb/redmine_airbrake_backend.png)](http://badge.fury.io/rb/redmine_airbrake_backend)
* [![Dependencies](https://gemnasium.com/ydkn/redmine_airbrake_backend.png?travis)](https://gemnasium.com/ydkn/redmine_airbrake_backend)
* [![Code Climate](https://codeclimate.com/github/ydkn/redmine_airbrake_backend.png)](https://codeclimate.com/github/ydkn/redmine_airbrake_backend)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
