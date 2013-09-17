namespace :redmine do
  namespace :airbrake_backend do
    desc 'Runs the plugin tests.'
    task :test do
      Rake::Task["redmine:airbrake_backend:test:units"].invoke
      Rake::Task["redmine:airbrake_backend:test:functionals"].invoke
      Rake::Task["redmine:airbrake_backend:test:integration"].invoke
    end

    namespace :test do
      desc 'Runs the plugin unit tests.'
      Rake::TestTask.new :units => "db:test:prepare" do |t|
        t.libs << "test"
        t.verbose = true
        t.pattern = "#{RedmineAirbrakeBackend.directory}/test/unit/**/*_test.rb"
      end

      desc 'Runs the plugin functional tests.'
      Rake::TestTask.new :functionals => "db:test:prepare" do |t|
        t.libs << "test"
        t.verbose = true
        t.pattern = "#{RedmineAirbrakeBackend.directory}/test/functional/**/*_test.rb"
      end

      desc 'Runs the plugin integration tests.'
      Rake::TestTask.new :integration => "db:test:prepare" do |t|
        t.libs << "test"
        t.verbose = true
        t.pattern = "#{RedmineAirbrakeBackend.directory}/test/integration/**/*_test.rb"
      end
    end
  end
end
