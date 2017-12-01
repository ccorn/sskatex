# SsKaTeX
## Server-side KaTeX for Ruby

This is a TeX-to-HTML+MathML+CSS converter class using the Javascript-based
[KaTeX], interpreted by one of the Javascript engines supported by [ExecJS].
The intended purpose is to eliminate the need for math-rendering Javascript
in the client's HTML browser. Therefore the name: SsKaTeX means *server-side*
KaTeX.

Javascript execution context initialization can be done once and then reused
for formula renderings with the same general configuration. As a result, the
performance is reasonable. Consider this a fast and lightweight alternative to
[mathjax-node-cli].

Requirements for using SsKaTeX:

* Ruby gem [ExecJS],
* A Javascript engine supported by ExecJS, e.g. via one of
    - Ruby gem [therubyracer],
    - Ruby gem [therubyrhino],
    - Ruby gem [duktape.rb],
    - [Node.js],
* `katex.min.js` from [KaTeX].

Although the converter only needs `katex.min.js`, you may need to serve the
rest of the KaTeX package, that is, CSS and fonts, as resources to the
targeted web browsers. The upside is that your HTML templates need no longer
include Javascripts for Math (neither `katex.js` nor any search-and-replace
script). Your HTML templates should continue referencing the KaTeX CSS.
If you host your own copy of the CSS, also keep hosting the fonts.

Minimal usage example:

    tex_to_html = SsKaTeX.new(katex_js: 'path-to-katex/katex.min.js')
    # Here you could verify contents of tex_to_html.js_source for security...

    body_html = '<p>By Pythagoras, %s. Furthermore:</p>' %
      tex_to_html.call('a^2 + b^2 = c^2', false)  # inline math
    body_html <<                                  # block display
      tex_to_html.call('\frac{1}{2} + \frac{1}{3} + \frac{1}{6} = 1', true)
    # etc, etc.

More configuration options are described in the Rdoc. Most options, with the
notable exception of `katex_opts`, do not affect usage nor output, but may be
needed to make SsKaTeX work with all the external parts (JS engine and KaTeX).
Since KaTeX is distributed separately from the SsKaTeX gem, configuration of
the latter must support the specification of Javascript file locations. This
implies that execution of arbitrary Javascript code is possible. Specifically,
options with `js` in their names should be accepted from trusted sources only.
Applications using SsKaTeX need to check this.

Also included is a command-line interface to the SsKaTeX gem: A script called
`sskatex`. It demonstrates basic functionality and options of the SsKaTeX gem.
It only renders one TeX math expression per invocation; try `sskatex -h` for
more information. If you want to see the SsKaTeX gem used more efficiently,
look at [kramdown] v1.16 or later which can use SsKaTeX as a math engine. But
do *not* make SsKaTeX available where kramdown is exposed to untrusted users;
that would be insecure unless that process is sandboxed.

[duktape.rb]: https://github.com/judofyr/duktape.rb#duktaperb
[ExecJS]: https://github.com/rails/execjs#execjs
[KaTeX]: https://khan.github.io/KaTeX/
[kramdown]: https://github.com/gettalong/kramdown
[mathjax-node-cli]: https://github.com/mathjax/mathjax-node-cli
[Node.js]: https://nodejs.org/
[therubyracer]: https://github.com/cowboyd/therubyracer#therubyracer
[therubyrhino]: https://github.com/cowboyd/therubyrhino#therubyrhino
