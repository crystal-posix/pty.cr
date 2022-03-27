require "./spec_helper"
require "../src/pty/process"

Signal::TTIN.trap { p "TTIN" }

describe Pty do
  buf = Bytes.new 1024

  it "ptsname" do
    Pty.open(width: 3, height: 20) do |pty|
      pty.ptsname.should be_a(String)
    end
  end

  it "puts/gets" do
    Pty.open(width: 3, height: 20) do |pty|
      pty.master.puts "foo"
      pty.slave.gets.should eq("foo")

      pty.ptsname.should be_a(String)
    end
  end

  it "close master" do
    Pty.open do |pty|
      pty.master.puts "foo"
      spawn do
        pty.slave.tcdrain # Must drain before close or buffer is discarded
        pty.master.close
      end
      pty.slave.gets.should eq "foo"
      pty.slave.read(Bytes.new(1)).should eq 0
    end
  end

  it "close slave" do
    Pty.open do |pty|
      pty.slave.puts "foo"
      spawn do
        pty.master.tcdrain # Must drain before close or buffer is discarded
        pty.slave.close
      end
      pty.master.gets.should eq "foo"
      pty.master.read(Bytes.new(1)).should eq 0
    end
  end

  it "eof" do
    Pty.open do |pty|
      pty.master.puts "foo"
      pty.slave.gets.should eq "foo"

      pty.master.write_byte 4_u8
      pty.slave.read(Bytes.new(1)).should eq 0
    end
  end
end

describe Pty::Process do
  it "run (x2)" do
    ptyp = Pty::Process.new
    2.times do # Make sure master is reusable
      r, status = ptyp.run("cat", ["-"]) do |_, wp, master|
        wp.puts "foo"
        wp.close
        master.gets.should eq("foo")
        :return_value
      end
      r.should eq(:return_value)

      # test discarding junk from prior `run`'s
      ptyp.pty.master.puts "bar"
    end
  end

  it "IO.copy" do
    ptyp = Pty::Process.new
    mio = IO::Memory.new
    r, status = ptyp.run("echo", ["-n", "foo"]) do |_, wp, master|
      wp.close
      IO.copy master, mio
      mio.to_s.should eq("foo")
      :return_value
    end
    r.should eq(:return_value)
  end
end
