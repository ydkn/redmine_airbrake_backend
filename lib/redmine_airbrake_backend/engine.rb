module RedmineAirbrakeBackend
  class Engine < ::Rails::Engine
    initializer 'redmine_airbrake_backend.register_redmine_plugin', after: :load_config_initializers do |app|
      register_plugin

      require_dependency 'airbrake_project_setting'
      require_dependency 'redmine_airbrake_backend/project_helper_patch'
    end

    private

    def register_plugin
      Redmine::Plugin.register :redmine_airbrake_backend do
        name 'Airbrake Backend'
        author 'Florian Schwab'
        description 'Airbrake Backend for Redmine'
        version '0.0.1'
        directory File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

        project_module :airbrake do
          permission :manage_airbrake, {airbrake: [:update]}
        end

        settings default: {hash_field: '', occurrences_field: ''}, partial: 'settings/airbrake'
      end
    end
  end
end
