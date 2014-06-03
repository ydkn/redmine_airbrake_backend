require 'active_support/concern'

module RedmineAirbrakeBackend::Patches
  module ProjectsHelper
    extend ActiveSupport::Concern

    included do
      alias_method_chain :project_settings_tabs, :airbrake_backend_tab
    end

    def project_settings_tabs_with_airbrake_backend_tab
      tabs = project_settings_tabs_without_airbrake_backend_tab

      tabs.push(
          name:    'airbrake',
          action:  :manage_airbrake,
          partial: 'projects/settings/airbrake',
          label:   :project_module_airbrake
        )

      tabs.select { |tab| User.current.allowed_to?(tab[:action], @project) }
    end
  end
end
