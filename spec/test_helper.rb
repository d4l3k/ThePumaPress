ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'rack/test'
require 'pry'

require File.expand_path '../../main.rb', __FILE__
