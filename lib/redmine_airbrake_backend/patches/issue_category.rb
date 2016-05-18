require 'active_support/concern'

module RedmineAirbrakeBackend::Patches
  module IssueCategory
    extend ActiveSupport::Concern

    included do
      has_many :airbrake_project_settings, foreign_key: :category_id, dependent: :nullify
    end
  end
end
