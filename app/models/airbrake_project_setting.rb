require 'redmine/safe_attributes'

class AirbrakeProjectSetting < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :project
  belongs_to :tracker
  belongs_to :category, class_name: IssueCategory.name
  belongs_to :priority, class_name: IssuePriority.name

  validates_presence_of :project_id

  safe_attributes :tracker_id, :category_id, :priority_id, :reopen_regexp, :reopen_repeat_description
end
