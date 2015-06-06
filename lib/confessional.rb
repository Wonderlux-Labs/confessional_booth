require 'rubygems'
require 'wisper'
require 'wisper/celluloid'

PHONE_HOOK_SWITCH = 4
DIALER_SWITCH = 5
PULSE_SWITCH = 6

class EventDispatcher
  include Wisper::Publisher

  def initialize
    @looper = Looper.new
    @call_count = 0
    @pulses = 0
    @processes_running = false
    @number_dialed = false
  end

  def setup
    do_subscriptions
  end

  def get_input
    get_physical_input
  end

  def get_physical_input
    puts "Program Started!"
    loop do
      next if phone_is_off
      if phone_is_dialing
        check_pulses
        @number_dialed = true
      end
      if !phone_is_dialing && @number_dialed
        puts @pulses
        start_playing if @pulses > 2 && @pulses < 6
        start_recording if @pulses >= 10
        @pulses = 0
        @number_dialed = false
      end
    end
  end

  private

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
      if @processes_running
        puts 'processes killed'
        kill_running_processes
      end
      return true
    end
  end

  def kill_running_processes
    puts 'trying to kill processes'
    broadcast(:kill_running_processes)
    @processes_running = false
  end

  def start_recording
    kill_running_processes if @processes_running
    broadcast(:start_recording)
    @processes_running = true
  end

  def start_playing
    kill_running_processes if @processes_running
    broadcast(:start_playing)
    @processes_running = true
  end

  private

  def do_subscriptions
    self.subscribe(Recorder.new)
    self.subscribe(Player.new)
  end
end

class Recorder

  def start_recording
    process_id = fork { recorder }
  end

  def kill_running_processes
    puts `killall arecord`
  end

  def recorder
    puts 'recording'
    file = 'wavs/' + rand(1_000_000).to_s + '.wav'
    puts `arecord -D hw:0,0 --format S16_LE --rate 44100 -c1 "#{file}"`
  end
end

class Player
  def start_playing
    fork { player }
  end

  def kill_running_processes
    puts `killall aplay`
  end

  def player
    file = Dir.glob('wavs/*.wav').sample
    if file
      puts `aplay -D hw:1,0 #{file}`
    else
      puts "no file to play"
    end
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