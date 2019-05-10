# Untis.rb

A Ruby-based WebUntis API wrapper for Untis Timetable Management System. Can be used with Rails.

## Installation

In your terminal:
```sh
gem install untis
```
or `Gemfile`:
```ruby
gem 'untis'
```

Then require it and authenticate where you need to:
```ruby
require 'untis'

::Untis = UntisWorker.new login: 'some_user', password: 'password', school_name: 'Super School'
Untis.authenticate!
```

The wrapper will maintain a living session to WebUntis API. If the session expires, it will automatically attempt to negotiate a new session until it succeeds.

## Usage

The library returns raw parsed JSON as string-indexed Hash, exactly how it is being returned by the WebUntis API. Example:
```
irb(main):001:0> Untis.get_teachers
=> {"jsonrpc"=>"2.0", "id"=>"3fa2785bdee9e601a0b038b79fdce10c", "result"=>[{"id"=>1, "name"=>"BA", "foreName"=>"Foo", "longName"=>"Bar", "title"=>"", "active"=>true, "dids"=>[]}]}
```

You can pass arguments to every single function as `snake_case` and in English, instead of the weird German/English mix, the wrapper will auto-translate your input into proper fields when it sends the request to the WebUntis API.

The wrapper does not do any permission checks, so be careful when using the API, since it may return error codes of it's own that the wrapper does not handle. If an error is returned by WebUntis API, it will simply be passed as return value, which you can then handle yourself. **The wrapper does not raise any exceptions.**

You can also use `Hashie::Mash` if you so wish in order to be able to access API return values like methods.

## Further documentation

[RubyDoc Documentation is available here.](https://www.rubydoc.info/gems/untis)
