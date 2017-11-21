# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2017 Christian Cornelssen <ccorn@1tein.de>
#
# This file is part of SsKaTeX which is licensed under the MIT.
#++

require 'json'

# This is a TeX-to-HTML+MathML+CSS converter class using the Javascript-based
# KaTeX[https://khan.github.io/KaTeX/], interpreted by one of the Javascript
# engines supported by ExecJS[https://github.com/rails/execjs#execjs].
# The intended purpose is to eliminate the need for math-rendering Javascript
# in the client's HTML browser. Therefore the name: SsKaTeX means _server-side_
# KaTeX.
#
# Javascript execution context initialization can be done once and then reused
# for formula renderings with the same general configuration. As a result, the
# performance is reasonable. Consider this a fast and lightweight alternative to
# mathjax-node-cli[https://github.com/mathjax/mathjax-node-cli].
#
# Requirements for using SsKaTeX:
#
# - Ruby gem ExecJS[https://github.com/rails/execjs#execjs],
# - A Javascript engine supported by ExecJS, e.g. via one of
#   - Ruby gem therubyracer[https://github.com/cowboyd/therubyracer#therubyracer],
#   - Ruby gem therubyrhino[https://github.com/cowboyd/therubyrhino#therubyrhino],
#   - Ruby gem duktape.rb[https://github.com/judofyr/duktape.rb#duktaperb],
#   - Node.js[https://nodejs.org/],
# - +katex.min.js+ from KaTeX[https://khan.github.io/KaTeX/].
#
# Although the converter only needs +katex.min.js+, you may need to serve the
# rest of the KaTeX package, that is, CSS and fonts, as resources to the
# targeted web browsers. The upside is that your HTML templates need no longer
# include Javascripts for Math (neither +katex.js+ nor any search-and-replace
# script). Your HTML templates should continue referencing the KaTeX CSS.
# If you host your own copy of the CSS, also keep hosting the fonts.
#
# Minimal usage example:
#
#     tex_to_html = SsKaTeX.new(katex_js: 'path-to-katex/katex.min.js')
#     # Here you could verify contents of tex_to_html.js_source for security...
#
#     body_html = '<p>By Pythagoras, %s. Furthermore:</p>' %
#       tex_to_html.call('a^2 + b^2 = c^2', false)  # inline math
#     body_html <<                                  # block display
#       tex_to_html.call('\frac{1}{2} + \frac{1}{3} + \frac{1}{6} = 1', true)
#     # etc, etc.
#
# More configuration options are described in the Rdoc. Most options, with the
# notable exception of #katex_opts, do not affect usage nor output, but may be
# needed to make SsKaTeX work with all the external parts (JS engine and KaTeX).
# Since KaTeX is distributed separately from the SsKaTeX gem, configuration of
# the latter must support the specification of Javascript file locations. This
# implies that execution of arbitrary Javascript code is possible. Specifically,
# options with +js+ in their names should be accepted from trusted sources only.
# Applications using SsKaTeX need to check this.
class SsKaTeX

  # Original value of the +EXECJS_RUNTIME+ environment variable, if any.
  # Used when deferring ExecJS's engine auto-selection.
  ENV_EXECJS_RUNTIME = ENV['EXECJS_RUNTIME']
  begin
    ::ENV['EXECJS_RUNTIME'] = 'Disabled'  # Defer automatic JS engine selection
    require 'execjs'
  ensure
    ::ENV['EXECJS_RUNTIME'] = ENV_EXECJS_RUNTIME
  end

  # Root directory for auxiliary files of this gem
  DATADIR = File.expand_path(File.join(File.dirname(__FILE__),
                                       '..', 'data', 'sskatex'))

  # The default for the #js_dir configuration option.
  # Path of a directory with Javascript helper files.
  DEFAULT_JS_DIR = File.join(DATADIR, 'js')

  # The default path to +katex.js+, cf. the #katex_js configuration option.
  # For a relative path, the starting point is the current working directory.
  DEFAULT_KATEX_JS = File.join('katex', 'katex.min.js')

  # The default for the #js_libs configuration option.
  # A list of UTF-8-encoded Javascript helper files to load.
  # Relative paths are interpreted relative to #js_dir.
  DEFAULT_JS_LIBS = ['escape_nonascii_html.js', 'tex_to_html.js']

  # This is a module with miscellaneous utility functions needed by SsKaTeX.
  module Utils
    # Dictionary for escape sequences used in Javascript string literals
    JS_ESCAPE = {
      "\\" => "\\\\",
      "\"" => "\\\"",
      # Escaping single quotes not necessary in double-quoted string literals
      #"'" => "\\'",
      # JS does not recognize \a nor GNU's \e
      # \b is ambiguous in regexps, as in Perl and Ruby
      #"\b" => "\\b",
      "\f" => "\\f",
      "\n" => "\\n",
      "\r" => "\\r",
      "\t" => "\\t",
      "\v" => "\\v",
    }
    private_constant :JS_ESCAPE

    # ExecJS uses <tt>runtime = Runtimes.const_get(name)</tt> without checks.
    # That is fragile and potentially insecure with arbitrary user input.
    # Instead we use a fixed dictionary restricted to valid contents.
    # Note that there are aliases like <tt>SpiderMonkey = Spidermonkey</tt>.
    JSRUN_FROMSYM = {}.tap do |dict|
      ExecJS::Runtimes.constants.each do |name|
        runtime = ExecJS::Runtimes.const_get(name)
        dict[name] = runtime if runtime.is_a?(ExecJS::Runtime)
      end
    end

    # Subclasses of +ExecJS::Runtime+ provide +.name+ (which is too verbose),
    # but not, say, +.symbol+. This dictionary associates each JS runtime
    # class with a representative symbol. For aliases like <tt>SpiderMonkey =
    # Spidermonkey</tt>, an unspecified choice is made.
    JSRUN_TOSYM = JSRUN_FROMSYM.invert

    class << self   # class-level methods
      # Turn a string into an equivalent Javascript literal, double-quoted.
      # Similar to +.to_json+, but escape all non-ASCII codes as well.
      def js_quote(str)
        # No portable way of escaping Unicode points above 0xFFFF
        '"%s"' % str.encode(Encoding::UTF_8).
        gsub(/[\0-\u{001F}\"\\\u{0080}-\u{FFFF}]/u) do |c|
          JS_ESCAPE[c] || "\\u%04x" % c.ord
        end
      end

      # This should really be provided by +ExecJS::Runtimes+:
      # A list of available JS engines, as symbols, in the order of preference.
      def js_runtimes
        ExecJS::Runtimes.runtimes.select(&:available?).map(&JSRUN_TOSYM)
      end

      # Configuration dicts may contain keys in both string and symbol form.
      # This bloats the output of +.to_json+ with duplicate key-value pairs.
      # While this does not affect the result, it looks strange in logfiles.
      # Therefore here is a function that recursively dedups dict keys,
      # removing symbolic keys if there are corresponding string keys.
      # Nondestructive.
      def dedup_keys(conf)
        # Lazy solution would be: JSON.parse(conf.to_json)
        case conf
        when Hash
          conf.reject {|key, _| key.is_a?(Symbol) && conf.has_key?(key.to_s)}.
            tap {|dict| dict.each {|key, value| dict[key] = dedup_keys(value)}}
        when Array
          conf.map {|value| dedup_keys(value)}
        else
          conf
        end
      end
    end
  end

  # This can be used for monitoring or debugging. When set to a
  #     proc {|level, &block| ...}
  # the #logger will be used internally as
  #     logger.call(level) {msg}
  # with the log message constructed in the given block. _level_ is one of:
  #
  # +:verbose+::
  #   For information about the effective engine configuration.
  #   Issued on first use of a changed configuration option.
  # +:debug+::
  #   For the Javascript expressions used when converting TeX.
  #   Issued once per TeX snippet.
  #
  # For example, to ignore +:debug+ yet trace +:verbose+ messages, set
  #     .logger = lambda {|level, &block| warn(block.call) if level == :verbose}
  # The default after construction is to log nothing.
  attr_accessor :logger

  # A dictionary with the used configuration options.
  # The resulting effective option values can be read from the same-named
  # attributes #katex_js, #katex_opts, #js_dir, #js_libs, #js_run.
  # See also #config=.
  def config
    @config
  end

  # Reconfigure the conversion engine by passing in a dictionary, without
  # affecting the #logger setting. Changes become effective on first use.
  #
  # Note: The dict will be shared by reference. Its deep object tree should
  # remain unchanged at least until #js_context or #call has been invoked.
  # Thereafter changes do not matter until #config= is assigned again.
  def config=(cfg)
    @js_context = nil
    @js_source = nil
    @katex_opts = nil
    @katex_js = nil
    @js_libs = nil
    @js_dir = nil
    @js_runtime = nil
    @js_run = nil
    @config = cfg
  end

  # Create a new instance configured with keyword arguments. Disable logging.
  # The keyword arguments can be retrieved as dictionary #config, and the
  # resulting effective option values can be read from the same-named attributes
  # #katex_js, #katex_opts, #js_dir, #js_libs, #js_run.
  def initialize(cfg = {})
    @logger = lambda {|level, &block|}
    self.config = cfg
  end

  # A symbol for the Javascript engine to be used. Recognized identifiers
  # include: +:RubyRacer+, +:RubyRhino+, +:Duktape+, +:MiniRacer+, +:Node+,
  # +:JavaScriptCore+, +:Spidermonkey+, +:JScript+, +:V8+, and +:Disabled+;
  # that last one would raise an error on first run (by #js_context).
  # Which engines are actually available depends on your installation.
  #
  # #js_run is determined on demand as follows and then cached for reuse.
  # If #config[ +:js_run+ ] is not defined, the contents of the environment
  # variable +EXECJS_RUNTIME+ will be considered instead; and if that is not
  # defined, an automatic choice will be made. For more information, set the
  # #logger to show +:verbose+ messages and consult the documentation of
  # ExecJS[https://github.com/rails/execjs#execjs].
  def js_run
    @js_run ||= begin
      log = lambda {|&block| @logger.call(:verbose, &block)}

      log.call {"Available JS runtimes: #{Utils.js_runtimes.join(', ')}"}
      jsrun = (@config[:js_run] ||
               ENV_EXECJS_RUNTIME ||
               Utils::JSRUN_TOSYM[ExecJS::Runtimes.best_available] ||
               'Disabled').to_s.to_sym
      log.call {"Selected JS runtime: #{jsrun}"}
      jsrun
    end
  end

  # The +ExecJS::Runtime+ subclass to be used, corresponding to #js_run.
  def js_runtime
    @js_runtime ||= Utils::JSRUN_FROMSYM[js_run]
  end

  # The path to a directory with Javascript helper files as specified by
  # #config[ +:js_dir+ ], or its default which is the subdirectory +js+ in the
  # data directory of SsKaTeX. There is no need to change that setting unless
  # you want to experiment with Javascript details.
  def js_dir
    @js_dir ||= @config[:js_dir] || DEFAULT_JS_DIR
  end

  # A list of UTF-8-encoded Javascript helper files to load.
  # Can be overridden with #config[ +:js_libs+ ].
  # Relative paths are interpreted relative to #js_dir.
  # The default setting (in YAML notation) is
  #
  #     js_libs:
  #       - escape_nonascii_html.js
  #       - tex_to_html.js
  #
  # And there is no need to change that unless you want to experiment with
  # Javascript details.
  #
  # Files available in the default #js_dir are:
  #
  # +escape_nonascii_html.js+::
  #   defines a function +escape_nonascii_html+ that converts non-ASCII
  #   characters to HTML numeric character references.
  #   Intended as postprocessing filter.
  # +tex_to_html.js+::
  #   defines a function +tex_to_html+(_tex_, _display_mode_, _katex_opts_)
  #   that takes a LaTeX math string, a boolean display mode (+true+ for block
  #   display, +false+ for inline), and a dict with general KaTeX options, and
  #   returns a string with corresponding HTML+MathML output. The implementation
  #   is allowed to set +katex_opts.displayMode+. SsKaTeX applies +tex_to_html+
  #   to each math fragment encountered.
  #   The implementation given here uses +katex.renderToString+ and
  #   postprocesses the output with +escape_nonascii_html+.
  def js_libs
    @js_libs ||= @config[:js_libs] || DEFAULT_JS_LIBS
  end

  # The path to your copy of +katex.min.js+ as specified by
  # #config[ +:katex_js+ ] or its default <tt>'katex/katex.min.js'</tt>.
  # For a relative path, the starting point is the current working directory.
  def katex_js
    @katex_js ||= @config[:katex_js] || DEFAULT_KATEX_JS
  end

  # A dictionary filled with the contents of #config[ +:katex_opts+ ] if given.
  # These are general KaTeX options such as +throwOnError+, +errorColor+,
  # +colorIsTextColor+, and +macros+. See the KaTeX
  # documentation[https://github.com/Khan/KaTeX#rendering-options] for details.
  # Use <tt>throwOnError: false</tt> if you want parse errors highlighted in the
  # HTML output rather than raised as exceptions when compiling.
  # Note that +displayMode+ is computed dynamically and should not be specified
  # here. Keys can be symbols or strings; if a key is given in both forms, the
  # symbol will be ignored.
  def katex_opts
    @katex_opts ||= Utils.dedup_keys(@config[:katex_opts] || {})
  end

  # The concatenation of the contents of the files in #js_libs, in #katex_js,
  # and a JS variable definition for #katex_opts, each item followed by a
  # newline. Created at first use. Can be used to validate JS contents if used
  # before #js_context.
  def js_source
    @js_source ||= begin
      log = lambda {|&block| @logger.call(:verbose, &block)}

      # Concatenate sources
      js = ''
      js_libs.each do |libfile|
        absfile = File.expand_path(libfile, js_dir)
        log.call {"Loading JS file: #{absfile}"}
        js << IO.read(absfile, external_encoding: Encoding::UTF_8) << "\n"
      end
      log.call {"Loading KaTeX JS file: #{katex_js}"}
      js << IO.read(katex_js, external_encoding: Encoding::UTF_8) << "\n"

      # Initialize JS variable katex_opts
      js_katex_opts = "var katex_opts = #{katex_opts.to_json}"
      log.call {"JS eval: #{js_katex_opts}"}
      js << js_katex_opts << "\n"
    end
  end

  # The JS engine context resulting from compilation of #js_source by the
  # #js_runtime selected with #js_run. Created at first use e.g. by #call.
  def js_context
    @js_context ||= js_runtime.compile(js_source)
  end

  # Given a TeX math fragment _tex_ as well as a boolean _display_mode_ (true
  # for block, false for inline), run the JS engine (using #js_context) and let
  # KaTeX compile the math fragment. Return the resulting HTML string.
  # Can raise errors if something in the process fails.
  def call(tex, display_mode)
    ctx = js_context
    js = "tex_to_html(#{Utils.js_quote(tex)}, #{display_mode.to_json}, katex_opts)"
    @logger.call(:debug) {"JS eval: #{js}"}
    ans = ctx.eval(js)
    raise (<<MSG) unless ans && ans.start_with?('<') && ans.end_with?('>')
KaTeX conversion failed!
Input:
#{tex}
Output:
#{ans}
MSG
    ans
  end
end
