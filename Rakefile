require 'rake/testtask'
require 'test/unit'

task :default => ["test:units"]

namespace :test do
  Rake::TestTask.new(:units) do |t|
    t.libs << "test"
    t.pattern = 'test/unit/**/*_test.rb'
  end

  Rake::TestTask.new(:smoke) do |t|
    t.libs << "test"
    t.pattern = 'test/smoke/**/*_test.rb'
  end

  task :ci do
    %w(unit smoke).each do |test|
      puts
      puts "Running #{test} tests"
      puts
      test = "units" if test == "unit"
      puts `time bundle exec rake test:#{test}`
      exit $?.exitstatus if $?.exitstatus != 0
    end
  end
end
