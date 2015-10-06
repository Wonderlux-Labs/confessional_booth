class DebuggerCommands
  include Wisper::Publisher

  def initialize(pulses)
    @pulses = pulses
    @text_speaker = TextSpeaker.new
    broadcast(:kill_running_processes)
  end

  def execute_command
    how_many_records if @pulses == 1
    delete_all_records if @pulses == 10
  end

  private

  def how_many_records
    array = Dir.glob(PROGRAM_DIR + '/wavs/*.wav')
    @text_speaker.speak "There are #{array.count} confessions"
  end

  def delete_all_records
    while file = Dir.glob(PROGRAM_DIR + '/wavs/*.wav').sample
      system("rm #{file}")
    end
    @text_speaker.speak('all files have been deleted')
  end
end

class ConfessionalCommands
  include Wisper::Publisher

  def initialize(pulses)
    @pulses = pulses
    @text_speaker = TextSpeaker.new
  end

  def execute_command
    case @pulses
    when 3
      start_playing
    when 10
      start_recording
    when 5
      save_last_played
    when 7
      play_saved
    else
      @text_speaker.speak('Sorry, I didnt quite get that, try again.
                          Dial 3 or 0. Or maybe 5 or 7.')
    end
  end

  private

  def save_last_played
    start_process [:save_last_played]
  end

  def start_process(process_array)
    broadcast(:kill_running_processes)
    process_array.each do |process|
      broadcast(process)
    end
    @processes_running = true
  end

  def play_saved
    start_process [:play_saved]
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
end

class ProcessKiller

  def kill_running_processes
    system('killall -9 aplay')
    system('killall -9 espeak')
    system('killall -9 arecord')
    false
  end
end
