class Pty
  class IO < IO::FileDescriptor
    getter temp_closed = Atomic(Int16).new 0

    def self.new(path : Path | String)
      fd = Crystal::System::File.open(path.to_s, "r+", 0o600)
      super(fd)
    end

    protected def unbuffered_read(slice : Bytes)
      # STDOUT.puts "#{self.class} #{fd} ubuf read #{slice.bytesize}"
      #    return 0 if @temp_closed.get == 1

      evented_read(slice, "Error reading file") do
        LibC.read(fd, slice, slice.size).tap do |return_code|
          if return_code == -1 && (Errno.value == Errno::EBADF || Errno.value == Errno::EIO)
            # STDOUT.puts "#{self.class} #{fd} ubuf err #{return_code} #{Errno.value}"
            # STDOUT.puts "#{self.class} #{fd} ubuf err #{String.new(slice[0, return_code.clamp(0,10)]).inspect}" if return_code > 0
            # Errno.value = 0
            return 0
            #           raise IO::Error.new "File not open for reading"
            # STDOUT.puts "#{self.class} #{fd} ubuf err #{return_code}"
          else
          end
        end
      end
      #     super(slice)
    end

    def tcflush : Nil
      r = C.tcflush(fd, C::TCIOFLUSH)
      raise Error.from_errno("tcflush") unless r == 0
    end
  end
end
