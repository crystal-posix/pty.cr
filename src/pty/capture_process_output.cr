require "../pty"

class Pty::CaptureProcessOutput
  getter pty = Pty.new

  # Run with a pipe as input.  Make sure to close the pipe or `cmd` may not exit
  #
  # See `Process#new` for a description of parameters
  def run(cmd : String, args = nil, *, shell : Bool = false, width = nil, height = nil)
    IO.pipe do |rpipe, wpipe|
      run(cmd, args, input: rpipe, shell: shell, width: width, height: height) do |process, _, outputerr|
        yield process, wpipe, outputerr
      end
    end
  end

  # Run with the specified input.  Make sure to close `input` or `cmd` may not exit
  #
  # See `Process#new` for a description of parameters
  def run(cmd : String, args = nil, *, input : IO::FileDescriptor, shell : Bool = false, width = nil, height = nil)
    # TODO: eat master data
    # TODO: set width,height
      process = Process.new(cmd, args, input: input, output: @pty.slave, error: @pty.slave, shell: shell)
      status = nil
      begin
        r = begin
          yield process, input, @pty.master
        rescue ex
          process.signal Signal::TERM
          raise ex
        ensure
          status = process.wait
        end
        {r, status.not_nil!}
      end
  end
end
