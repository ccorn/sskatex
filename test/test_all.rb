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
    @tex2html = SsKaTeX.new
  end

  TESTDIR = File.dirname(__FILE__)

  # Generate test methods
  Dir[File.join(TESTDIR, 'tex', '*.tex')].each do |tex_file|
    testcase = File.basename(tex_file, '.tex').tr('^a-zA-Z0-9_', '_')
    [:none, :static, :dynamic].each do |logger_lifetime|
      ['block', 'span'].each do |display_mode|
        name = "#{testcase}_#{logger_lifetime}_#{display_mode}"
        define_method("test_#{name}") do
          logged = {}
          logger = lambda {|level, &block| logged[level] = true}
          static_logger = (logger if logger_lifetime == :static)
          dynamic_logger = (logger if logger_lifetime == :dynamic)
          @tex2html.logger = static_logger
          tex = IO.read(tex_file, external_encoding: Encoding::UTF_8).chomp
          ref_html_file = File.join(TESTDIR, display_mode, testcase) + '.html'
          ref_html = IO.read(ref_html_file,
                             external_encoding: Encoding::UTF_8).chomp
          html = @tex2html.call(tex, display_mode == 'block', &dynamic_logger)
          assert_equal html, ref_html
          if logger_lifetime == :none
            assert logged.empty?
          else
            assert logged[:verbose]
            assert logged[:debug]
            assert logged.size == 2
          end
          assert @tex2html.logger == static_logger
        end
      end
    end
  end
end
