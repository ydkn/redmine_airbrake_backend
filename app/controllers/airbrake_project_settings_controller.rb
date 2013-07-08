class AirbrakeProjectSettingsController < ::ApplicationController
  before_filter :find_project

  menu_item :settings

  def update
    @airbrake_project_setting = @project.airbrake_settings || AirbrakeProjectSetting.new(project: @project)

    @airbrake_project_setting.tracker = @project.trackers.where(id: params[:airbrake_project_setting][:tracker_id]).first
    @airbrake_project_setting.category = @project.issue_categories.where(id: params[:airbrake_project_setting][:category_id]).first
    @airbrake_project_setting.priority = IssuePriority.where(id: params[:airbrake_project_setting][:priority_id]).first
    @airbrake_project_setting.reopen_regexp = params[:airbrake_project_setting][:reopen_regexp]

    @airbrake_project_setting.save

    redirect_to settings_project_path(@project, :tab => 'airbrake')
  end

  private

  def find_project
    @project = Project.find(params[:id])
  end

end
