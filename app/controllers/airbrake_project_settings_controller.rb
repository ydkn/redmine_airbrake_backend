# Controller for project-specific airbrake settings
class AirbrakeProjectSettingsController < ::ApplicationController
  before_filter :find_project
  before_filter :find_airbrake_setting

  menu_item :settings

  def update
    @airbrake_project_setting.tracker_id                = params[:airbrake_project_setting][:tracker_id]
    @airbrake_project_setting.category_id               = params[:airbrake_project_setting][:category_id]
    @airbrake_project_setting.priority_id               = params[:airbrake_project_setting][:priority_id]
    @airbrake_project_setting.reopen_regexp             = params[:airbrake_project_setting][:reopen_regexp]
    @airbrake_project_setting.reopen_repeat_description = params[:airbrake_project_setting][:reopen_repeat_description]

    if @airbrake_project_setting.save
      flash[:notice] = l(:notice_successful_update)
    end

    redirect_to settings_project_path(@project, tab: 'airbrake')
  end

  private

  def find_project
    @project = Project.find(params[:id])
  end

  def find_airbrake_setting
    @airbrake_project_setting = @project.airbrake_settings || AirbrakeProjectSetting.new
    @airbrake_project_setting.project = @project
  end
end
