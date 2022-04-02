# pty.cr
[![Crystal CI](https://github.com/crystal-posix/pty.cr/actions/workflows/crystal.yml/badge.svg)](https://github.com/crystal-posix/pty.cr/actions/workflows/crystal.yml)
[![GitHub release](https://img.shields.io/github/release/crystal-posix/pty.cr.svg)](https://github.com/crystal-posix/pty.cr/releases)
![GitHub commits since latest release (by date) for a branch](https://img.shields.io/github/commits-since/crystal-posix/pty.cr/latest)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://crystal-posix.github.io/pty.cr/main)

Pty control and utility classes to capture command output.

Thread (-Dpreview_mt) safe.

Inspired from [crpty](https://github.com/federicotdn/crpty).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crpty:
       github: crystal-posix/pty.cr
   ```

2. Run `shards install`

## Usage

### Capture output from a command preserving colors & window width/height
```crystal
require "pty/process"

ptyp = Pty::Process.new
rvalue, process_status = ptyp.run("cat", ["-"]) do |process, stdin, stdouterr|
  spawn do # Must run in another Fiber to avoid blocking if reading from `stdouterr`
    File.open("input") { |f| IO.copy(f, stdin) }
  ensure
    stdin.close # Indicate no more input to child process
  end

  while line = stdouterr.gets
    puts stdouterr
  end

  :return_value
end

p process_status
raise "cmd failed" unless process_status.success?
```

### Raw pty
```crystal
require "pty"

pty = Pty.new
pty.master.puts "foo"
pty.slave.gets => "foo"

pty.slave.win_size = {40, 80}
```

## Contributing

1. Fork it (<https://github.com/crystal-posix/pty/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Didactic Drunk](https://github.com/didactic-drunk) - creator & maintainer
