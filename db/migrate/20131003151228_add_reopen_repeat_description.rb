class AddReopenRepeatDescription < ActiveRecord::Migration
  def up
    add_column :airbrake_project_settings, :reopen_repeat_description, :boolean

    AirbrakeProjectSetting.reset_column_information

    AirbrakeProjectSetting.find_each do |s|
      s.reopen_repeat_description = false
      s.save!
    end

    change_column :airbrake_project_settings, :reopen_repeat_description, :boolean, null: false, default: false
  end

  def down
    remove_column :airbrake_project_settings, :reopen_repeat_description
  end
end
