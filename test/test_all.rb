# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2017 Christian Cornelssen <ccorn@1tein.de>
#
# This file is part of SsKaTeX which is licensed under the MIT.
#++

require 'minitest/autorun'
require 'sskatex'

class SsKaTeXTest < Minitest::Test
  def setup
    @tex2html = SsKaTeX.new do |level, &block|
#      warn(block.call) if level == :verbose
    end
  end

  TESTDIR = File.dirname(__FILE__)

  # Generate test methods
  Dir[File.join(TESTDIR, 'tex', '*.tex')].each do |f|
    testcase = File.basename(f, '.tex').tr('^a-zA-Z0-9_', '_')
    ['block', 'span'].each do |mode|
      define_method("test_#{testcase}_#{mode}") do
        tex = IO.read(f, external_encoding: Encoding::UTF_8).chomp
        html = IO.read(File.join(TESTDIR, mode, testcase) + '.html',
                       external_encoding: Encoding::UTF_8).chomp
        assert_equal @tex2html.call(tex, mode == 'block'), html
      end
    end
  end
end
