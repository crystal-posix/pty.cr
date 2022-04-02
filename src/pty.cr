require "./pty/file_descriptor"
require "./pty/io"

class Pty
  class Error < Exception
    include SystemError
  end

  private PTS_NAME_MUTEX = Mutex.new

  @@tty_io : ::IO::FileDescriptor?
  @@tty_io_set = false

  private MUTEX = Mutex.new

  def self.tty_win_size
    tty_io.try &.win_size
  end

  protected def self.tty_io
    return @@tty_io if @@tty_io_set
    MUTEX.synchronize do
      @@tty_io ||= STDIN if STDIN.tty?
      @@tty_io ||= STDOUT if STDOUT.tty?
      @@tty_io ||= STDERR if STDERR.tty?
      @@tty_io ||= File.new("/dev/tty")
      @@tty_io_set = true
    end
    @@tty_io
  end

  {% if flag?(:linux) %}
    @[Link("util")]
  {% end %}
  lib C
    TCIOFLUSH = 2 # Linux

    fun openpty(amaster : LibC::Int*, aslave : LibC::Int*, name : LibC::Char*, termp : LibC::Termios*, winsize : LibC::Winsize*) : LibC::Int
    fun login_tty(int : LibC::Int) : LibC::Int
    fun grantpt(int : LibC::Int) : LibC::Int
    fun ptsname(fd : LibC::Int) : LibC::Char* # Not thread safe

    fun tcdrain(fd : LibC::Int) : LibC::Int
    fun tcflush(fd : LibC::Int, qs : LibC::Int) : LibC::Int
  end

  def self.open(width = nil, height = nil)
    pty = new(width: width, height: height)
    yield pty ensure pty.close
  end

  getter master : Pty::IO
  getter slave : Pty::IO

  def initialize(width = nil, height = nil)
    tio = self.class.tty_io
    term = uninitialized LibC::Termios
    if tio
      r = LibC.tcgetattr(tio.fd, pointerof(term))
      raise Error.from_errno("tcgetattr") unless r == 0
    end
    r = C.openpty(out amaster, out aslave, nil, tio ? pointerof(term) : Pointer(LibC::Termios).null, nil)
    raise Error.from_errno("openpty") unless r == 0

    @master = Pty::IO.new amaster
    @slave = Pty::IO.new aslave
    @master.sync = true
    @slave.sync = true
    @master.close_on_exec = true
    @slave.close_on_exec = true
    @master.blocking = false
    @slave.blocking = false

    if width && height
      @slave.win_size = {width, height}
    elsif width || height
      raise ArgumentError.new("must provide both or neither width and height")
    elsif tio
      @slave.win_size = tio.win_size
    end
  end

  def open
    @master.tcflush

    if @slave.closed?
      @slave = Pty::IO.new(ptsname)
    else
      @slave.tcflush
    end

    yield
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
