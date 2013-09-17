require 'active_support/concern'

module RedmineAirbrakeBackend::Patches
  module IssueCategory
    extend ActiveSupport::Concern

    included do
      has_many :airbrake_project_settings, dependent: :nullify
    end
  end
end
