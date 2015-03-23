# Project-specific settings for airbrake
class AirbrakeProjectSetting < ActiveRecord::Base
  belongs_to :project
  belongs_to :tracker
  belongs_to :category, class_name: IssueCategory.name
  belongs_to :priority, class_name: IssuePriority.name

  validates :project_id, presence: true
end
