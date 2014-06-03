class CreateAirbrakeProjectSettings < ActiveRecord::Migration
  def up
    create_table :airbrake_project_settings do |t|
      t.references :project, index: true, null: false
      t.references :tracker
      t.references :category
      t.references :priority
      t.string :reopen_regexp
      t.timestamps
    end
  end

  def down
    drop_table :airbrake_project_settings
  end
end
