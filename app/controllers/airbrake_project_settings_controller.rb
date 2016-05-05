# Controller for project-specific airbrake settings
class AirbrakeProjectSettingsController < ::ApplicationController
  before_filter :find_project
  before_filter :find_airbrake_setting

  menu_item :settings

  def update
    if @airbrake_project_setting.update(airbrake_project_setting_params)
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

  def airbrake_project_setting_params
    params.require(:airbrake_project_setting).permit(:tracker_id, :category_id, :priority_id, :reopen_regexp, :reopen_repeat_description)
  end
end
