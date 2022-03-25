require "../pty"

class Pty::CaptureProcessOutput
  getter pty = Pty.new

  def run(cmd : String, args = nil, *, width = nil, height = nil)
    # TODO: eat master data
    # TODO: set width,height
    IO.pipe do |rp, wp|
      process = Process.new(cmd, args, input: rp, output: @pty.slave, error: @pty.slave)
      status = nil
      begin
        r = begin
          yield process, wp, @pty.master
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
end
