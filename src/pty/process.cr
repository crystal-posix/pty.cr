require "../pty"

# Wrap `::Process.run` with a pipe for stdin and `Pty` for stdout/stderr
class Pty::Process
  getter pty = Pty.new
  @process = Atomic(::Process?).new nil

  # Run with a pipe as input.  Make sure to close the pipe or `cmd` may not exit
  #
  # See `::Process#new` for a description of parameters
  def run(cmd : String, args = nil, *, shell : Bool = false, width = nil, height = nil, win_size = nil)
    IO.pipe do |rpipe, wpipe|
      run(cmd, args, input: rpipe, shell: shell, width: width, height: height, win_size: win_size) do |process, _, outputerr|
        yield process, wpipe, outputerr
      end
    end
  end

  # Run with the specified input.  Make sure to close `input` or `cmd` may not exit
  #
  # See `::Process#new` for a description of parameters
  def run(cmd : String, args = nil, *, input : IO::FileDescriptor, shell : Bool = false, width = nil, height = nil, win_size = nil)
    win_size = {width, height} if width && height
    pty.master.win_size = win_size if win_size

    pty.open do
      process = ::Process.new(cmd, args, input: input, output: pty.slave, error: pty.slave, shell: shell)
      @process.set process
      status = nil
      begin
        pty.slave.close # Remains open in `process`

        r = begin
          yield process, input, pty.master
        rescue ex
          process.signal(Signal::TERM) rescue nil
          raise ex
        ensure
          status = process.wait
        end
        {r, status.not_nil!}
      ensure
        @process.set nil
      end
    end
  end

  # Attempt to signal running `Process`
  # Beware of race conditions
  def signal?(sig) : Bool
    if process = @process.get
      process.signal sig
      true
    else
      false
    end
  end
end
