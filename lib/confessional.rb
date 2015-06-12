require 'rubygems'
require 'wisper'
require 'wisper/celluloid'
require 'piface'
require 'pry'

PHONE_HOOK_SWITCH = 5
DIALER_SWITCH = 6
PULSE_SWITCH = 7
PROGRAM_DIR = File.expand_path(File.join(File.dirname(__FILE__), '../'))

class EventDispatcher
  include Wisper::Publisher

  def initialize
    @looper = Looper.new
    @pulses = 0
    @processes_running = false
    @number_dialed = false
    @hangup_count = 0
    @been_used = false
    @debug_mode = false
  end

  def setup
    do_subscriptions
  end

  def get_input
    puts "Program Started"
    get_physical_input
  end

  def get_physical_input
    loop do
      next if phone_is_off
      @been_used = true
      if phone_is_dialing
        check_pulses
        @number_dialed = true
      end
      if !phone_is_dialing && @number_dialed
        puts @pulses
        if @debug_mode
          delete_all_records if @pulses >= 10
          turn_off_debug_mode
        else
          start_playing if @pulses > 2 && @pulses <= 6
          start_recording if @pulses >= 10
          start_debugging if @pulses == 7
        end
        @pulses = 0
        @number_dialed = false
      end
    end
  end

  private

  def turn_off_debug_mode
    @debug_mode = false
    puts `espeak "debugger mode turned off"`
  end

  def turn_on_debug_mode
    @debug_mode = true
    puts `espeak "debugging mode active"`
  end

  def delete_all_records
    while file = Dir.glob(PROGRAM_DIR + '/wavs/*.wav').sample
      puts `rm #{file}`
    end
    puts `espeak "all files have been deleted"`
  end

  def check_memory
    space_left = `df -m /`.split(/\b/)[24].to_i
    while space_left < 200 && file = Dir.glob(PROGRAM_DIR + '/wavs/*.wav').sample
      puts `rm #{file}`
      puts "FILE REMOVED - #{file}"
      space_left = `df -m /`.split(/\b/)[24].to_i
    end
  end

  def check_pulses
    while phone_is_dialing
      if Piface.read(PULSE_SWITCH) == 0
        @pulses += 1
        @looper.loop_until_1(PULSE_SWITCH)
      end
    end
  end

  def phone_is_dialing
    Piface.read(DIALER_SWITCH) == 0
  end

  def phone_is_off
    if Piface.read(PHONE_HOOK_SWITCH) == 0
      turn_off_debug_mode if @debug_mode
      if @processes_running
        kill_running_processes
        @hangup_count = 1
      end
      check_memory
      if @been_used
        @hangup_count += 1
        @been_used = false
      end
      if @hangup_count == 10
        turn_on_debug_mode
      end
      return true
    end
  end

  def kill_running_processes
    broadcast(:kill_running_processes)
    puts `killall -9 aplay`
    puts `killall -9 espeak`
    puts `killall -9 arecord`
    @processes_running = false
  end

  def start_process(process_array)
    kill_running_processes
    process_array.each do |process|
      broadcast(process)
    end
    @processes_running = true
  end

  def start_recording
    start_process [:start_recording, :start_lights]
  end

  def start_playing
    start_process [:start_playing]
  end

  def start_debugging
    start_process [:start_debugging]
  end

  private

  def do_subscriptions
    self.subscribe(Recorder.new)
    self.subscribe(Player.new)
    self.subscribe(Debugger.new)
    self.subscribe(LightController.new)
  end
end

class LightController
  def initialize
    @light_array = [3]
  end

  def start_lights
    @light_array.each do |n|
      Piface.write(n, 1)
    end
  end

  def kill_running_processes
    @light_array.each do |n|
      Piface.write(n, 0)
    end
  end
end

class Recorder

  def initialize
    @is_recording = false
    @process_id_array = []
    @priest_responses = [
      "Welcome, child. Please record your confession at the beep and hang up when you are finished.",
      "You know what to do at the beep.",
      "I am a machine that offers forgiveness. Confess at the beep."
    ]
  end

  def start_recording
    @process_id_array << fork { recorder }
    @is_recording = true
  end

  def kill_running_processes
    @process_id_array.each do |pid|
      puts `kill -9 #{pid}`
    end
    @process_id_array = []
    @is_recording = false
  end

  def recorder
    puts `espeak "#{random_priest_response}"`
    beep = PROGRAM_DIR + '/wavs/beep/beep.wav'
    puts `aplay -D hw:1,0 #{beep}`
    file = PROGRAM_DIR + '/wavs/' + rand(1_000_000).to_s + '.wav'
    puts `arecord -D hw:0,0 --format S16_LE --rate 44100 -d 60 -c1 "#{file}"`
    puts `espeak "I'm sorry, your time is up"`
    exit
  end

  def random_priest_response
    if rand(10) > 5
      @priest_responses.sample
    else
      @priest_responses[0]
    end
  end
end

class Debugger
  def start_debugging
    process_id = fork { debugger }
  end

  def debugger
    puts `aplay -l`
    puts `arecord -l`
    exit
  end
end

class Player
  def initialize
    @process_id_array = []
  end

  def start_playing
    @process_id_array << fork { player }
  end

  def kill_running_processes
    @process_id_array.each do |pid|
      puts `kill -9 #{pid}`
    end
    @process_id_array = []
  end

  def player
    file = Dir.glob(PROGRAM_DIR + '/wavs/*.wav').sample
    if file
      puts `aplay -D hw:1,0 #{file}`
    else
      puts `espeak "sorry, something went wrong"`
    end
    exit
  end
end

class Looper
  def loop_until_0(n)
    loop do
      input = Piface.read n
      break if input == 0
      sleep 0.1
    end
  end

  def loop_until_1(n)
    loop do
      input = Piface.read n
      break if input == 1
      sleep 0.1
    end
  end
end