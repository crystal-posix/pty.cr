require "./pty/file_descriptor"

class Pty
  class Error < Exception
    include SystemError
  end

  private PTS_NAME_MUTEX = Mutex.new

  @@tty_io : IO::FileDescriptor?
  @@tty_io_set = false

  def self.tty_io
    return @@tty_io if @@tty_io_set
    @@tty_io = nil
    @@tty_io = STDIN if STDIN.tty?
    @@tty_io = STDOUT if STDOUT.tty?
    @@tty_io = STDERR if STDERR.tty?
    @@tty_io_set = true
    @@tty_io
  end

  {% if flag?(:linux) %}
    @[Link("util")]
  {% end %}
  lib C
    fun openpty(amaster : LibC::Int*, aslave : LibC::Int*, name : LibC::Char*, termp : LibC::Termios*, winsize : LibC::Winsize*) : LibC::Int
    fun login_tty(int : LibC::Int) : LibC::Int
    fun grantpt(int : LibC::Int) : LibC::Int
    fun ptsname(fd : LibC::Int) : LibC::Char* # Not thread safe
  end

  def self.open(width = nil, height = nil)
    pty = new(width: width, height: height)
    yield pty ensure pty.close
  end

  getter master : IO::FileDescriptor
  getter slave : IO::FileDescriptor

  def initialize(width = nil, height = nil)
    tio = self.class.tty_io
    term = uninitialized LibC::Termios
    if tio
      r = LibC.tcgetattr(tio.fd, pointerof(term))
      raise Error.from_errno("tcgetattr") unless r == 0
    end
    r = C.openpty(out amaster, out aslave, nil, tio ? pointerof(term) : Pointer(LibC::Termios).null, nil)
    raise Error.from_errno("openpty") unless r == 0

    @master = IO::FileDescriptor.new amaster
    @slave = IO::FileDescriptor.new aslave

    if width && height
      @slave.win_size = {width, height}
    elsif width || height
      raise ArgumentError.new("must provide both or neither width and height")
    elsif tio
      @slave.win_size = tio.win_size
    end
  end

  def login_tty!
    r = LibUtil.login_tty slave.fd
    raise Error.from_errno("login_tty") unless r == 0
  end

  def ptsname
    PTS_NAME_MUTEX.synchronize do
      String.new C.ptsname(@master.fd)
    end
  end

  def close
    @master.close
    @slave.close
  end
end
