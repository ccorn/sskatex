# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2017 Christian Cornelssen <ccorn@1tein.de>
#
# This file is part of SsKaTeX which is licensed under the MIT.
#++

Gem::Specification.new do |s|
  s.name        = 'sskatex'
  s.version     = '0.9.30'
  s.date        = '2017-11-30'
  s.summary     = "Server-side KaTeX for Ruby"
  s.description = <<DESC
This is a TeX-to-HTML+MathML+CSS converter class using the Javascript-based
KaTeX, interpreted by one of the Javascript engines supported by ExecJS.
The intended purpose is to eliminate the need for math-rendering Javascript
in the client's HTML browser. Therefore the name: SsKaTeX means Server-side
KaTeX.

Javascript execution context initialization can be done once and then reused
for formula renderings with the same general configuration. As a result, the
performance is reasonable.

The configuration supports arbitrary locations of the external file katex.min.js
as well as custom Javascript for pre- and postprocessing.
For that reason, the configuration must not be left to untrusted users.
DESC
  s.author      = "Christian Cornelssen"
  s.email       = 'ccorn@1tein.de'
  s.homepage    = 'https://github.com/ccorn/sskatex'
  s.license     = 'MIT'
  s.add_runtime_dependency 'execjs', '~> 2.7'
  s.add_development_dependency 'duktape', '~> 1.6', '>= 1.6.1'
  s.required_ruby_version = '>= 2.1'
  s.requirements << "Javascript engine supported by the ExecJS gem"
  s.requirements << "Some KaTeX release"
  s.rdoc_options << '-a'
  s.files       = Dir["LICENSE.txt", "README.md",
                      "bin/sskatex",
                      "lib/sskatex.rb",
                      "test/test_all.rb",
                      "test/{block,span}/*.html", "test/tex/*.tex",
                      "data/sskatex/js/*.js"]
  s.executables << 'sskatex'
end
