require "ioctl"

class IO::FileDescriptor
  alias WinSizeArg = {Int32, Int32}

  def win_size : WinSizeArg
    wsize = uninitialized LibC::Winsize
    IOCTL.ioctl(fd, IOCTL::TIOCGWINSZ, pointerof(wsize))

    {wsize.ws_col.to_i, wsize.ws_row.to_i}
  end

  def win_size=(args : WinSizeArg) : WinSizeArg
    wsize = LibC::Winsize.new
    wsize.ws_col = args[0]
    wsize.ws_row = args[1]

    IOCTL.ioctl(fd, IOCTL::TIOCSWINSZ, pointerof(wsize))

    args
  end

  # blocking
  def tcdrain : Nil
    r = Pty::C.tcdrain fd
    raise Error.from_errno("tcdrain") unless r == 0
  end
end
