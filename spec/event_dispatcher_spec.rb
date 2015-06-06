require_relative 'spec_helper'
require 'stringio'

describe EventDispatcher do
  before :each do
    @ed = EventDispatcher.new
  end

  it "should do something" do
    expect(@ed).to be_an_instance_of EventDispatcher
  end

  it "should publish a start recording event" do
    expect { @ed.send(:start_recording) }.to broadcast(:start_recording)
  end

  it "should publish a start playing event" do
    expect { @ed.send(:start_playing) }.to broadcast(:start_playing)
  end

  it "should publish an event that kills all processes" do
    expect { @ed.send(:kill_running_processes) }.to broadcast(:kill_running_processes)
  end
end

# describe Recorder do
#   before :each do
#     @recorder = instance_double('Recorder')
#   end

#   it "should respond to the start_recording event" do
#     ed = EventDispatcher.new
#     ed.subscribe(@recorder)
#     ed.send(:start_recording)
#     stub_wisper_publisher("EventDispatcher", :execute, :start_recording)
#     expect(@recorder).to receive(:start_recording)
#   end
# end