require 'active_support/concern'

module RedmineAirbrakeBackend::Patches
  module Project
    extend ActiveSupport::Concern

    included do
      has_one :airbrake_settings, class_name: AirbrakeProjectSetting.name, dependent: :destroy
    end
  end
end
