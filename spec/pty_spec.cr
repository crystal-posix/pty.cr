require "./spec_helper"
require "../src/pty/capture_process_output"

describe Pty do
  it "openpty" do
    IO.pipe do |rp, wp|
      Pty.open(width: 3, height: 20) do |pty|
        wp.puts "foobar"
        wp.close

        pty.ptsname.should be_a(String)

        Process.run("cat", ["-"], input: rp, output: pty.slave)
        pty.master.gets.should eq("foobar")
      end
    end
  end
end

describe Pty::CaptureProcessOutput do
  it "run" do
    cpo = Pty::CaptureProcessOutput.new
    r, status = cpo.run("cat", ["-"]) do |_, wp, master|
      wp.puts "foo"
      wp.close
      master.gets.should eq("foo")
      :return
    end
    r.should eq(:return)
  end
end
