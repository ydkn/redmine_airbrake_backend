::ProjectsHelper.module_eval %Q{
  alias_method :project_settings_tabs_original_airbrake, :project_settings_tabs

  def project_settings_tabs
    tabs = project_settings_tabs_original_airbrake

    tabs.push({
        :name => 'airbrake',
        :action => :manage_airbrake,
        :partial => 'projects/settings/airbrake',
        :label => :project_module_airbrake
      })

    tabs.select{|tab| User.current.allowed_to?(tab[:action], @project)}
  end
}
