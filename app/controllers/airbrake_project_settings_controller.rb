class AirbrakeProjectSettingsController < ::ApplicationController
  before_filter :find_project

  menu_item :settings

  def update
    @airbrake_project_setting = @project.airbrake_settings || AirbrakeProjectSetting.new(project: @project)
    @airbrake_project_setting.safe_attributes = params[:airbrake_project_setting]

    @airbrake_project_setting.save

    flash[:notice] = l(:notice_successful_update)
    redirect_to settings_project_path(@project, :tab => 'airbrake')
  end

  private

  def find_project
    @project = Project.find(params[:id])
  end

end
