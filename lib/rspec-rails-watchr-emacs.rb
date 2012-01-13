# coding: utf-8)

require 'rspec-rails-watchr-emacs/version'
require 'term/ansicolor'
require 'socket'

class SpecWatchr
  String.send :include, Term::ANSIColor

  
  module CommandLine
    def terminal_columns
      cols = `stty -a`.scan(/ (\d+) columns/).flatten.first
      $?.success? ? cols.to_i : nil
    end

    def run cmd
      puts "=== running: #{cmd} ".ljust(terminal_columns, '=').cyan
      results = `#{cmd}`
      success = $?.success?
      unless @custom_extract_summary_proc
        puts "    " + results.split("\n")[@error_count_line].strip.send(success ? :green : :red)
      end
      puts "===".ljust(terminal_columns, '=').cyan
      # {:success => success, :results => message}
      results
    end

    def clear!
      system 'clear'
    end
  end

  module EmacsConnection
    def alist (hash)
      hash.merge(:magic_convert_to => :alist)
    end
    def flatten (hash)
      hash.merge(:magic_convert_to => :flat)
    end
    def keyword (symbol)
      :"#{symbol.inspect}"
    end
    def elispify_symbol(symbol)
      symbol.to_s.gsub(/_/,'-') 
    end
    def hash_to_esexp (hash)
      h = hash.clone
      h.delete(:magic_convert_to)
      case hash[:magic_convert_to]
      when :alist
        res = h.map { |k, v| "(#{object_to_esexp k} . #{object_to_esexp v})" }
        "(#{res.join(' ')})"
      when :flat
        res = h.map { |k, v| "#{object_to_esexp k} #{object_to_esexp v}" }
        "(#{res.join(' ')})"
      else
        if hash.keys.reduce(true) { |base, el| base && Symbol === el }
          res = h.map { |k, v| "#{object_to_esexp keyword(k)} #{object_to_esexp v}" }
          "(#{res.join(' ')})"
        else
          h[:magic_convert_to] = :alist
          hash_to_esexp h
        end
      end
    end
    def object_to_esexp (object)
      case object
      when String
        object.inspect
      when Array
        res = object.map { |el| object_to_esexp(el) }
        "(#{res.join(' ')})"
      when Symbol
        elispify_symbol(object)
      when Hash
        hash_to_esexp object
      else
        object.to_s
      end
    end
    def esend (object)
      msg = object_to_esexp object
      @sock.puts("|#{msg.length}|#{msg}")
      # @sock.print("|#{msg.length}|")
      # sleep 2
      # @sock.puts msg
    end

    def rspec_status(err_cnt)
      if err_cnt[:errors] > 0
        :failure
      elsif err_cnt[:pending] > 0
        :pending
      else
        :success
      end
    end

    def extract_rspec_counts(results, line)
      err_line = results.split("\n")[line]
      err_regex = /^(\d*)\sexamples?,\s(\d*)\s(errors?|failures?)[^\d]*((\d*)\spending)?/
      _, examples, errors, _, pending = (err_line.match err_regex).to_a
      summ = { :examples => examples.to_i, :errors => errors.to_i, :pending => pending.to_i }
      summ.merge(:status => rspec_status(summ))
    end

    def extract_rspec_summary(results)
      case @custom_extract_summary_proc
      when Proc
        @custom_extract_summary_proc.call(results)
      else
        begin
          extract_rspec_counts(results, @error_count_line)
        rescue
          puts "--- Error while matching error counts.".red
          print "--- Summary line number: ".yellow
          @error_count_line = STDIN.gets.to_i
          extract_rspec_summary results
        end
      end
    end

    def format_help(summary)
      h = "#{summary[:errors]} errors\n"
      h << ("#{summary[:pending]} pending\n" if summary[:pending]>0).to_s
      h << "\nmouse-1: switch to result buffer"
    end

    
    def eregister
      esend :register => @enotify_slot_id, :handler_fn => :enotify_rspec_result_message_handler
    end

      
    
    def esend_results(results)
      summ = extract_rspec_summary(results)
      status = summ[:status]
      message = { :id => @enotify_slot_id,
        :notification => {
          :text => @notification_message[status],
          :face => @notification_face[status],
          :help => format_help(summ),
          :mouse_1 => :enotify_rspec_mouse_1_handler},
        :data => results,
      }
      esend message
    end
  end 
        

  module Specs

    def rspec_command
      @rspec_command ||= File.exist?('./.rspec') ? 'rspec' : 'spec'
    end

    def rspec_send_results(results)
      begin
        print "--- Sending notification to #{@enotify_host}:#{@enotify_port}" \
        " through #{@enotify_slot_id}... ".cyan
        esend_results results 
        puts "Success!".green
      rescue
        puts "Failed!".red
        init_network
        rspec_send_results results 
      end
    end

    def check_if_bundle_needed
      if `bundle exec #{rspec_command} -v` == `#{rspec_command} -v` 
        @bundle = ""
      else
        @bundle = "bundle exec "
      end
    end

    def rspec options
      unless options.empty?
        results = run("#{@bundle}#{rspec_command} #{options}")
        # notify( success ? '♥♥ SUCCESS :) ♥♥' : '♠♠ FAILED >:( ♠♠' )
        rspec_send_results(results)
      end
    end

    def rspec_all
      rspec 'spec'
    end

    def rspec_files *files
      rspec files.join(' ')
    end

    def specs_for(path)
      print "--- Searching specs for #{path.inspect}...".yellow
      specs = match_specs path, Dir['spec/**/*_spec.rb']
      puts specs.empty? ? ' nothing found.'.red : " #{specs.size} matched.".green
      specs
    end

    def default_rails_matcher path, specs
      specs.grep(/\b#{path}((_spec)?\.rb)?$/)
    end

    def match_specs path, specs
      matched_specs = @custom_matcher.call(path, specs) if @custom_matcher
      matched_specs = default_rails_matcher(path, specs) if matched_specs.nil?
    end
  end

  module Control
    def exit_watchr
      @exiting = true
      puts '--- Exiting...'.white
      exit
    end

    def abort_watchr!
      puts '--- Forcing abort...'.white
      abort("\n")
    end

    def reload!
      # puts ARGV.join(' ')
      exec('bundle exec watchr')
    end

    def reload_file_list
      require 'shellwords'
      system "touch #{__FILE__.shellescape}"
      # puts '--- Watch\'d file list reloaded.'.green
    end

    def trap_int!
      # Ctrl-C

      @interrupted ||= false

      Signal.trap('INT') { 
        puts  ' (Interrupted with CTRL+C)'.red
        if @interrupted
          @exiting ? abort_watchr : exit_watchr
        else
          @interrupted = true
          # reload_file_list
          print '--- What to do now? (q=quit, a=all-specs, r=reload): '.yellow
          case STDIN.gets.chomp.strip.downcase
          when 'q'; @interrupted = false; exit_watchr
          when 'a'; @interrupted = false; rspec_all
          when 'r'; @interrupted = false; reload!
          else
            @interrupted = false
            puts '--- Bad input, ignored.'.yellow
          end
          puts '--- Waiting for changes...'.cyan
        end
      }
    end
  end



  include CommandLine
  include Specs
  include Control
  include EmacsConnection

  def blank_string?(string)
    string =~ /\A\s*\n?\z/
  end

  def rescue_sock_error
    print "--- Enter Enotify host [localhost:5000]: ".yellow
    host_and_port = STDIN.gets.strip
    if blank_string?(host_and_port)
      @enotify_host, @enotify_port = ['localhost', @default_options[:enotify_port]]
    else
      @enotify_host, @enotify_port = host_and_port.split(/\s:\s/) 
      @enotify_port = @enotify_port.to_i
    end
    init_network
  end
    
  def init_network
    begin
      print "=== Connecting to emacs... ".cyan
      @sock = TCPSocket.new(@enotify_host, @enotify_port)
      eregister
      puts "Success!".green
    rescue
      puts "Failed!".red
      rescue_sock_error
    end
  end

  def initialize watchr, options = {}
    @default_options = {
      :enotify_port => 5000,
      :enotify_host => 'localhost',
      :notification_message => {:failure => "F", :success => "S", :pending => "P"},
      :notification_face => {
        :failure => keyword(:failure),
        :success => keyword(:success),
        :pending => keyword(:warning)},
      # custom_extract_summary_proc: takes the result text as argument
      # and returns an hash of the form
      # {:errors => #errors
      #  :pending => #pending
      #  :examples => #examples
      #  :status => (:success|:failure|:pending) }
      :custom_extract_summary_proc => nil, 
      :error_count_line => -1,

      # custom_matcher : takes two arguments: the path of the modified
      # file (CHECK) and an array of spec files. Returns an array of
      # matching spec files for the path given.
      :custom_matcher => nil     }

    options = @default_options.merge(options)
    puts "========OPTIONS=========="
    puts options
    puts "========================="
    @enotify_host = options[:enotify_host]
    @enotify_port = options[:enotify_port]
    @notification_message = options[:notification_message]
    @notification_face = options[:notification_face]
    @custom_extract_summary_proc = options[:custom_extract_summary_proc]
    @error_count_line = options[:error_count_line]
          
    @custom_matcher = options[:custom_matcher]
    
    yield if block_given?
    @enotify_slot_id = ((File.basename Dir.pwd).split('_').map { |s| s.capitalize }).join
    check_if_bundle_needed
    init_network
    @watchr = watchr


    
    
    

    watchr.watch('^spec/(.*)_spec\.rb$')                     {|m| rspec_files specs_for(m[1])}
    watchr.watch('^(?:app|lib|script)/(.*)(?:\.rb|\.\w+|)$') {|m| rspec_files specs_for(m[1].gsub(/\.rb$/,''))}

    trap_int!

    puts '--- Waiting for changes...'.cyan
  end
end


class Object
  module Rspec
    module Rails
      module Watchr
        def self.new *args, &block
          SpecWatchr.new *args, &block
        end
      end
    end
  end
end
