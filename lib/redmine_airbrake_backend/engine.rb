require 'redmine_airbrake_backend/version'

module RedmineAirbrakeBackend
  class Engine < ::Rails::Engine
    initializer 'redmine_airbrake_backend.register_redmine_plugin', after: 'load_config_initializers' do |app|
      register_redmine_plugin
    end

    initializer 'redmine_airbrake_backend.apply_patches', after: 'redmine_airbrake_backend.register_redmine_plugin' do |app|
      ActionDispatch::Callbacks.to_prepare do
        require_dependency 'redmine_airbrake_backend/patches/project' unless defined?(RedmineAirbrakeBackend::Patches::Project)
        require_dependency 'redmine_airbrake_backend/patches/tracker' unless defined?(RedmineAirbrakeBackend::Patches::Tracker)
        require_dependency 'redmine_airbrake_backend/patches/issue_category' unless defined?(RedmineAirbrakeBackend::Patches::IssueCategory)
        require_dependency 'redmine_airbrake_backend/patches/issue_priority' unless defined?(RedmineAirbrakeBackend::Patches::IssuePriority)
        require_dependency 'redmine_airbrake_backend/patches/projects_helper' unless defined?(RedmineAirbrakeBackend::Patches::ProjectsHelper)

        RedmineAirbrakeBackend::Engine.apply_patch(Project, RedmineAirbrakeBackend::Patches::Project)
        RedmineAirbrakeBackend::Engine.apply_patch(Tracker, RedmineAirbrakeBackend::Patches::Tracker)
        RedmineAirbrakeBackend::Engine.apply_patch(IssueCategory, RedmineAirbrakeBackend::Patches::IssueCategory)
        RedmineAirbrakeBackend::Engine.apply_patch(IssuePriority, RedmineAirbrakeBackend::Patches::IssuePriority)
        RedmineAirbrakeBackend::Engine.apply_patch(ProjectsHelper, RedmineAirbrakeBackend::Patches::ProjectsHelper)
      end
    end

    def apply_patch(clazz, patch)
      clazz.send(:include, patch) unless clazz.included_modules.include?(patch)
    end

    private

    def register_redmine_plugin
      Redmine::Plugin.register :redmine_airbrake_backend do
        name             'Airbrake Backend'
        author           'Florian Schwab'
        author_url       'https://github.com/ydkn'
        description      'Airbrake Backend for Redmine'
        url              'https://github.com/ydkn/redmine_airbrake_backend'
        version          ::RedmineAirbrakeBackend::VERSION
        requires_redmine version_or_higher: '2.4.0'
        directory        RedmineAirbrakeBackend.directory

        project_module :airbrake do
          permission :manage_airbrake, { airbrake: [:update] }
        end

        settings default: { hash_field: '', occurrences_field: '' }, partial: 'settings/airbrake'
      end
    end
  end
end
