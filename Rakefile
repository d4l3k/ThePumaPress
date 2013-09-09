require 'sinatra/asset_pipeline/task.rb'
require './main'

Bundler.require('test')

Sinatra::AssetPipeline::Task.define! Sinatra::Application

task 'pry' do
    binding.pry
end

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.pattern = "spec/*_spec.rb"
end
