require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task default: [:test]

namespace :dev do
  desc "Check for SsKaTeX availability"
  task :test_sskatex_deps do
    katexjs = 'katex/katex.min.js'
    raise (<<TKJ) unless File.exists? katexjs
Cannot find file '#{katexjs}'.
You need to download KaTeX e.g. from https://github.com/Khan/KaTeX/releases/
and extract at least '#{katexjs}'.
Alternatively, if you have a copy of KaTeX unpacked somewhere else,
you can create a symbolic link 'katex' pointing to that KaTeX directory.
TKJ
    html = `echo a | #{RbConfig.ruby} -Ilib bin/sskatex -v`
    raise (<<KTC) unless $?.success?
Some requirement by SsKaTeX or the employed JS engine has not been satisfied.
Cf. the above error messages.
If you 'gem install sskatex', also make sure that some JS engine is available,
e.g. by installing one of the gems 'duktape', 'therubyracer', or 'therubyrhino'.
KTC
    raise (<<XJS) unless / class="katex"/ === html
Hmmm... SsKaTeX produces output which does not seem like KaTeX output.
You are experimenting, huh?
XJS
    puts "SsKaTeX is available, and its default configuration works."
  end

  desc "Update SsKaTeX test reference outputs"
  task update_katex_tests: [:test_sskatex_deps] do
    # Not framed in terms of rake file tasks to prevent accidental overwrites.
    ['block', 'span'].each do |display|
      Dir['test/tex/*.tex'].each do |texfile|
        stem = File.basename(texfile, '.tex')
        html = File.join('test', display, stem + '.html')
        disp = "--#{'no-' if display != 'block'}display"
        ruby "-Ilib bin/sskatex #{disp} #{texfile} #{html}"
      end
    end
  end
end
