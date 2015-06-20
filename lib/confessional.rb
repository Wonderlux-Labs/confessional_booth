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
    @text_speaker = TextSpeaker.new
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
      if phone_is_dialing
        pulses = check_pulses
      end
      if @number_dialed && !phone_is_dialing && pulses
        trigger_event_from_number(pulses)
      end
    end
  end

  def trigger_event_from_number(pulses)
    if @debug_mode
      trigger_debugger_event_from_number(pulses)
    else
      trigger_normal_event_from_number(pulses)
    end
    @number_dialed = false
  end

  def trigger_normal_event_from_number(pulses)
    case pulses
    when 3
      start_playing
    when 10
      start_recording
    when 7
      start start_debugging
    else
      puts "unknown number - #{pulses}"
    end
  end

  def trigger_debugger_event_from_number(pulses)
    delete_all_records if pulses == 10
    turn_off_debug_mode
  end

  def turn_off_debug_mode
    @debug_mode = false
    @text_speaker.speak('debugger mode turned off')
  end

  def turn_on_debug_mode
    @debug_mode = true
    @text_speaker.speak('debugger mode active')
  end

  def delete_all_records
    while file = Dir.glob(PROGRAM_DIR + '/wavs/*.wav').sample
      system("rm #{file}")
    end
    @text_speaker.speak('all files have been deleted')
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
      turn_on_debug_mode if @hangup_count == 10
      return true
    end
  end

  def kill_running_processes
    broadcast(:kill_running_processes)
    system('killall -9 aplay')
    system('killall -9 espeak')
    system('killall -9 arecord')
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
    subscribe(Recorder.new)
    subscribe(Player.new)
    subscribe(Debugger.new)
    subscribe(LightController.new)
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
      'Welcome, child. Please record your confession at the beep and hang up when you are finished.',
      'You know what to do at the beep.',
      'I am a machine that offers forgiveness. Confess at the beep.'
    ]
    @wav_player = WavPlayer.new
    @wav_recorder = WavRecorder.new
    @text_speaker = TextSpeaker.new
  end

  def start_recording
    @process_id_array << fork { recorder }
    @is_recording = true
  end

  def kill_running_processes
    @process_id_array.each do |pid|
      system("kill -9 #{pid}")
    end
    @process_id_array = []
    @is_recording = false
  end

  def recorder
    @text_speaker.speak(random_priest_response)
    play_beep
    file = PROGRAM_DIR + '/wavs/' + rand(1_000_000).to_s + '.wav'
    recorder = @wav_recorder.record(file)
    @text_speaker.speak("I'm sorry your time is up") if recorder
    exit
  end

  def play_beep
    beep = PROGRAM_DIR + '/wavs/beep/beep.wav'
    @wav_player.play(beep)
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
    fork { debug_sound_cards }
  end

  def debug_sound_cards
    system('aplay -l')
    system('arecord -l')
    exit
  end
end

class Player
  def initialize
    @process_id_array = []
    @wav_player = WavPlayer.new
    @text_speaker = TextSpeaker.new
    @sorry_message = 'Sorry, something went wrong. Maybe try recording something first'
  end

  def start_playing
    @process_id_array << fork { player }
  end

  def kill_running_processes
    @process_id_array.each do |pid|
      system("kill -9 #{pid}")
    end
    @process_id_array = []
  end

  def player
    file = Dir.glob(PROGRAM_DIR + '/wavs/*.wav').sample
    file ? @wav_player.play(file) : @text_speaker.speak(@sorry_message)
    exit
  end
end

class WavPlayer
  def play(file)
    system("aplay -D hw:1,0 #{file}")
  end
end

class WavRecorder
  def record(file)
    system("arecord -D hw:0,0 --format S16_LE --rate 44100 -d 60 -c1 #{file}")
  end
end

class TextSpeaker
  def speak(text)
    system("espeak -ven-uk -k5 -s150 '#{text}'")
  end
end

# Used for pausing program until circuit changes
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
