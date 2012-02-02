# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rspec-rails-watchr-emacs/version"

Gem::Specification.new do |s|
  s.name        = 'rspec-rails-watchr-emacs'
  s.version     = Rspec::Rails::Watchr::VERSION
  s.authors     = %w[Alessandro Piras]
  s.email       = %w[laynor@gmail.com]
  s.homepage    = 'https://github.com/laynor/espectator'
  s.summary     = %q{Watches specs for a Rails (2 or 3) project - notifications via Emacs enotify}
  s.description = %q{Watches specs for a Rails (2 or 3) project - notifications via Emacs enotify. Fork of rspec-rails-watchr (spectator)}
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = %w[lib]
  
  s.add_dependency 'watchr'
  s.add_dependency 'term-ansicolor'
  s.add_dependency 'notify'
end
