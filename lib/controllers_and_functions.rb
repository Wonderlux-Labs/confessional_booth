
# Controller for LEDs
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

# Main Recording Object
class Recorder
  def initialize
    @is_recording = false
    @process_id_array = []
    @priest_responses = [
      'Welcome, child. Please record your confession at the beep and
       hang up when you are finished.',
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

# Confession Player Object
class Player
  def initialize
    @process_id_array = []
    @wav_player = WavPlayer.new
    @text_speaker = TextSpeaker.new
    @sorry_message = 'Sorry, something went wrong.
                      Maybe try recording something first'
    @last_played = nil
    @saved_file = nil
  end

  def start_playing
    file = get_random_file
    @process_id_array << fork { player(file) }
    @last_played = file
  end

  def play_saved
    file = @saved_file
    if file
      @process_id_array << fork { player(file) }
    else
      @text_speaker.speak('Sorry, nothing has been saved yet.')
    end
  end

  def save_last_played
    @saved_file = @last_played
    @text_speaker.speak ('Okay, I saved it!')
  end

  def kill_running_processes
    @process_id_array.each do |pid|
      system("kill -9 #{pid}")
    end
    @process_id_array = []
  end

  def get_random_file
    file = Dir.glob(PROGRAM_DIR + '/wavs/*.wav').sample
    @text_speaker.speak(@sorry_message) unless file
    file
  end

  def player(file = nil)
    @wav_player.play(file) if file
  end
end

# WAV file player
class WavPlayer
  def play(file)
    system("aplay -D hw:1,0 #{file}")
  end
end

# WAV file recorder
class WavRecorder
  def record(file)
    system("arecord -D hw:0,0 --format S16_LE --rate 44100 -d 60 -c1 #{file}")
  end
end

# Text to Speech
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

# Generates the dialtone
class DialtoneGenerator
  def initialize
    @process_id_array = []
    @wav_player = WavPlayer.new
    @text_speaker = TextSpeaker.new
    @random_responses = ['Hey buddy, are you gonna confess or what?',
                         'Time to shit or get off the pot',
                         'Tell me something juicy!',
                         'Maybe you should hang up the phone',
                         'La La La La La La']
  end

  def play_dialtone
    @process_id_array << fork { loop_dialtone }
  end

  def loop_dialtone
    loop do
      dialtone = PROGRAM_DIR + '/wavs/beep/dialtone.wav'
      @wav_player.play(dialtone)
      @text_speaker.speak(@random_responses.sample)
    end
  end

  def kill_running_processes
    @process_id_array.each do |pid|
      system("kill -9 #{pid}")
    end
    @process_id_array = []
  end
end