class AirbrakeProjectSetting < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :project
  Project.has_one :airbrake_settings, class_name: AirbrakeProjectSetting.name, dependent: :destroy

  belongs_to :tracker
  Tracker.has_many :airbrake_project_settings, dependent: :nullify

  belongs_to :category, class_name: IssueCategory.name
  IssueCategory.has_many :airbrake_project_settings, dependent: :nullify

  belongs_to :priority, class_name: IssuePriority.name
  IssuePriority.has_many :airbrake_project_settings, dependent: :nullify

  validates_presence_of :project_id

  safe_attributes :tracker_id, :category_id, :priority_id, :reopen_regexp
end
