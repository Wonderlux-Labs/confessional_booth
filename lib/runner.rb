require 'piface'
require 'pry'
require_relative 'confessional'

dispatcher = EventDispatcher.new
dispatcher.setup
dispatcher.get_input
