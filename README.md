# ESpectator (a fork of [Spectator][spectator] that integrates with emacs)

ESpectator provides discreet notifications in the emacs modeline, via
the [Enotify][enotify] emacs notification system.

Test results are displayed in an emacs buffer, so no more switching
between emacs and the window were the test results are displayed are
necessary :-)

If you hate growl-style popups and prefer a simple indicator on the
modeline, ESpectator is for you. It's best used together with
[RSpec Org Formatter][RSpecOrgFormatter], which provides org formatted
test results that do look nice on emacs.

## Usage

### Emacs side

You need to install [Enotify][enotify] first. Please refer to its
README for this step.

Note that enotify uses the TCP port 5000 to listen to notification
messages. If you specified a different port, refer to the ``Advanced''
section of this document to see how to specify various ESpectator
options

### Watchr

In your specs.watchr file just add:

```ruby
	require 'rspec-rails-watchr-emacs'
	@specs_watchr ||= Rspec::Rails::Watchr.new(self)
```

Then launch `watchr` as usual (probably `bundle exec watchr`).
If you are using RspecOrgFormatter, see the *Advanced* section of this document.

### Instructions

The normal behavior is similar to `autotest --fast-start --no-full-after-failed` 
but gives the user a bit more control over execution. By hitting CTRL+C (or CMD+. on OSX)
you get the following prompt:

    ^C (Interrupted with CTRL+C)
    --- What to do now? (q=quit, a=all-specs, r=reload): 

### Advanced

ESpectator supports the following options (here reported with their
default values):
```ruby
	{ :enotify_port => 5000, # TCP port for the enotify connection
      :enotify_host => 'localhost', # host name for the enotify connection
      :notification_message => { # Text displayed on the modeline when
	    :failure => "F",         # there is at least 1 failing spec
		:success => "S",         # there are no failing or pending spec
		:pending => "P"          # there are no failing spec and at least 1 pending
	  },
      :notification_face => { # Face used to display the text in the modeline
        :failure => keyword(:failure),
        :success => keyword(:success),
        :pending => keyword(:warning)},
	  #
      # custom_extract_summary_proc: takes the result text as argument
      # and returns an hash of the form
      # {:errors => #errors
      #  :pending => #pending
      #  :examples => #examples
      #  :status => (:success|:failure|:pending) }
      :custom_extract_summary_proc => nil, 
	  #
	  # index of the Rspec summary line.
	  # It should look like this:
	  # 25 examples, 2 failures, 1 pending
      :error_count_line => -1,
	  #
	  # A proc that takes two arguments |path, specs|
	  # where path is the file that has been modified
	  # and specs is a vector containing all the spec
	  # files.
	  # It should return a vector containing the matching
	  # specs for `path'.
      :custom_matcher => nil
	}
```
An example of a custom matcher:

```ruby
    @specs_watchr ||= Rspec::Rails::Watchr.new(self,
	   :custom_matcher => lambda { |path, specs|
			   case path
			   when %r{lib/calibration_with_coefficients}
				 specs.grep(%r{models/(logarithmic|polynomial)_calibration})
			   when %r{app/models/telemetry_parameter}
				 specs.grep(%r{models/telemetry_parameter})
			   end
			   })
```

To use it with the [RSpec Org Formatter][RSpecOrgFormatter], the 
:error_count_line option should be set to -6:
```ruby
	@specs_watchr ||= Rspec::Rails::Watchr.new(self, :error_count_line => -6)
```


Copyright (c) 2012 Alessandro Piras, 2011 Elia Schito, released under the MIT license
