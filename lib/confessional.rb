require 'rubygems'
require 'wisper'
require 'piface'
require 'pry'
require_relative 'controllers_and_functions'
require_relative 'event_commanders'

PHONE_HOOK_SWITCH = 5
DIALER_SWITCH = 6
PULSE_SWITCH = 7
PROGRAM_DIR = File.expand_path(File.join(File.dirname(__FILE__), '../'))

# Main runner object
class EventDispatcher
  include Wisper::Publisher

  def initialize
    @text_speaker = TextSpeaker.new
    @processes_running = false
    @number_dialed = false
    @hangup_count = 0
    @been_used = false
    @debug_mode = false
    @dialtone_on = false
  end

  def setup
    do_subscriptions
  end

  def get_input
    knock_the_door
    dialer_loop
  end

  private

  def knock_the_door
    puts 'Program Started'
    2.times do |n|
      Piface.write(n, 1)
      sleep(0.5)
      Piface.write(n, 0)
      sleep(0.5)
    end
  end

  def dialer_loop
    loop do
      next if phone_is_off
      @been_used = true
      if @dialtone_on == false
        broadcast(:play_dialtone)
        @dialtone_on = true
      end
      pulses = check_pulses if phone_is_dialing
      if @number_dialed && !phone_is_dialing && pulses
        trigger_event_from_number(pulses)
      end
    end
  end

  def trigger_event_from_number(pulses)
    broadcast(:kill_running_processes)
    if @debug_mode
      commander = DebuggerCommands.new(pulses)
    else
      commander = ConfessionalCommands.new(pulses)
    end
    @processes_running = commander.execute_command
    turn_off_debug_mode if @debug_mode
    @number_dialed = false
  end

  def turn_on_debug_mode
    @debug_mode = true
    @text_speaker.speak('debugger mode active')
  end

  def turn_off_debug_mode
    @debug_mode = false
    @text_speaker.speak('debugger mode turned off')
  end

  def check_memory
    space_left = `df -m /`.split(/\b/)[24].to_i
    while space_left < 200 && file = Dir.glob(PROGRAM_DIR + '/wavs/*.wav').sample
      system("rm #{file}")
      puts "FILE REMOVED - #{file}"
      space_left = `df -m /`.split(/\b/)[24].to_i
    end
  end

  def check_pulses
    @number_dialed = true
    pulses = 0
    input = 0
    while phone_is_dialing
      new_input = Piface.read(PULSE_SWITCH)
      if new_input != input
        sleep 0.01
        new_input = Piface.read(PULSE_SWITCH)
        if input == 0 && new_input == 1
          pulses += 1
        end
        input = new_input
      end
    end
    pulses - 1
  end

  def phone_is_dialing
    Piface.read(DIALER_SWITCH) == 0
  end

  def phone_is_off
    if Piface.read(PHONE_HOOK_SWITCH) == 0
      @hangup_count = 1 if @processes_running
      if @processes_running || @dialtone_on == true
        broadcast(:kill_running_processes)
        @dialtone_on = false
        @processes_running = false
      end
      turn_off_debug_mode if @debug_mode
      check_memory
      if @been_used
        @hangup_count += 1
        @been_used = false
      end
      turn_on_debug_mode if @hangup_count == 10
      return true
    end
  end

  private

  def do_subscriptions
    Wisper.subscribe(DialtoneGenerator.new)
    Wisper.subscribe(Player.new)
    Wisper.subscribe(Recorder.new)
    Wisper.subscribe(ProcessKiller.new)
  end
end
