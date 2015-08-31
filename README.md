NAME
====

P6SGI - Perl 6 Web Server Gateway Interface Specification

STATUS
======

This is a Proposed Draft.

Version 0.4.Draft

0 INTRODUCTION
==============

This document standardizes the interface to be implemented by web application developers in Perl 6. It provides a standard protocol by which application servers may communicate with web applications.

This standard has the following goals:

  * Standardize the interface between server and application so that web developers may focus on application development rather than the nuances of supporting each of several server platforms.

  * Keep the interface simple so that a web application or middleware requires no additional tools or libraries other than what exists in a standard Perl 6 environment, no module installations are required.

  * Keep the interface simple so that servers and middleware are simple to implement.

  * Allow the interface to flexible enough to accomodate a variety of common use-cases and simple optimzations.

  * Provide flexibility so that unanticipated use-cases may be implemented and so that the interface may be extended by servers wishing to do so.

  * Allow for backwards compatibility to PSGI applications.

Aside from that is the underlying assumption that this is a simple interface and ought to at least somewhat resemble work in the standards it is derived from, including Rack, WSGI, PSGI, CGI, and others.

1 TERMINOLOGY
=============

A P6SGI application is a Perl 6 routine that expects to receive an environment from an *application server* and returns a response each time it is called by the server.

A Web Server is an application that processes requests and responses according to the HTTP protocol.

An application server is a program that is able to provide an environment to a *P6SGI application* and process the value returned from such an application.

The *application server* might be associated with a *web server*, might itself be a *web server*, might process a protocol used to communicate with a *web server* (such as CGI or FastCGI), or may be something else entirely not related to a *web server* (such as a tool for testing *P6SGI applications*).

Middleware is a *P6SGI application* that wraps another *P6SGI application* for the purpose of performing some auxiliary task such as preprocessing request environments, logging, postprocessing responses, etc.

A framework developer is a developer who writes an *application server*.

An application developer is a developer who writes a *P6SGI application*.

2 SPECIFICATION
===============

This specification is divided into three layers: Layer 0: Server, Layer 1: Middleware, and Layer 2: Application.

2.0 Layer 0: Server
-------------------

A P6SGI application server is a program capable of running P6SGI applications as defined by this specification.

### 2.0.0 Locating Applications

The server MUST be able to find applications somehow.

It SHOULD be able to load applications found in P6SGI script files. These are Perl 6 code files that end with the definition of a block to be used as the application routine. For example:

    use v6;
    sub app(%env) {
        Promise.start({
            200, [ Content-Type => 'text/plain' ], [ 'Hello World!' ]
        })
    }

### 2.0.1 The Environment

The environment MUST be an [Associative](Associative). The keys of this map are mostly derived the old Common Gateway Interface (CGI) as well as a number of additional P6SGI-specific values. The application server MUST provide each key as the type given. All variables given in the table below MUST be supported, except for those with the `p6sgix.` prefix.

This list is primarily adopted from [PSGI](PSGI).

<table>
  <thead>
    <tr>
      <td>Variable</td>
      <td>Constraint</td>
      <td>Description</td>
    </tr>
  </thead>
  <tr>
    <td><code>REQUEST_METHOD</code></td>
    <td><code>Str:D where *.chars > 0</code></td>
    <td>The HTTP request method, such as "GET" or "POST".</td>
  </tr>
  <tr>
    <td><code>SCRIPT_NAME</code></td>
    <td><code>Str:D where any('', m{ ^ "/" })</code></td>
    <td>This is the initial prtion of the URL path that refers to the application.</td>
  </tr>
  <tr>
    <td><code>PATH_INFO</code></td>
    <td><code>Str:D where any('', m{ ^ "/" })</code></td>
    <td>This is the remainder of the request URL path within the application. This value SHOULD be URI decoded by the application server according to L<RFC 3875|http://www.ietf.org/rfc/rfc3875></td>
  </tr>
  <tr>
    <td><code>REQUEST_URI</code></td>
    <td><code>Str:D</code></td>
    <td>This is the exact URL sent by the client in the request line of the HTTP request. The application server SHOULD NOT perform any decoding on it.</td>
  </tr>
  <tr>
    <td><code>QUERY_STRING</code></td>
    <td><code>Str:D</code></td>
    <td>This is the portion of the requested URL following the <code>?</code>, if any.</td>
  </tr>
  <tr>
    <td><code>SERVER_NAME</code></td>
    <td><code>Str:D where *.chars > 0</code></td>
    <td>This is the server name of the web server.</td>
  </tr>
  <tr>
    <td><code>SERVER_PORT</code></td>
    <td><code>Int:D where * > 0</code></td>
    <td>This is the server port of the web server.</td>
  </tr>
  <tr>
    <td><code>SERVER_PROTOCOL</code></td>
    <td><code>Str:D where *.chars > 0</code></td>
    <td>This is the server protocol sent by the client. Typically set to "HTTP/1.1" or a similar value.</td>
  </tr>
  <tr>
    <td><code>CONTENT_LENGTH</code></td>
    <td><code>Int:_</code></td>
    <td>This corresponds to the Content-Length header sent by the client. If no such header was sent the application server SHOULD set this key to the L<Int> type value.</td>
  </tr>
  <tr>
    <td><code>CONTENT_TYPE</code></td>
    <td><code>Str:_</code></td>
    <td>This corresponds to the Content-Type header sent by the cilent. If no such header was sent the application server SHOULD set this key to the L<Str> type value.</td>
  </tr>
  <tr>
    <td><code>HTTP_*</code></td>
    <td><code>Str:_</code></td>
    <td>The remaining request headers are placed here. The names are prefixed with <code>HTTP_</code>, in ALL CAPS with the hyphens ("-") turned to underscores ("_"). Multiple incoming headers with the same name should be joined with a comma (", ") as described in L<RFC 2616|http://www.ietf.org/rfc/rfc2616>. The <code>HTTP_CONTENT_LENGTH</code> and <code>HTTP_CONTENT_TYPE</code> headers MUST NOT be set.</td>
  </tr>
  <tr>
    <td>Other CGI Keys</td>
    <td><code>Str:_</code></td>
    <td>The server SHOULD attempt to provide as many other CGI variables as possible, but no others are required or formally specified.</td>
  </tr>
  <tr>
    <td><code>p6sgi.version</code></td>
    <td><code>Version:D</code></td>
    <td>This is the version of this specification, <code>v0.3.Draft</code>.</td>
  </tr>
  <tr>
    <td><code>p6sgi.url-scheme</code></td>
    <td><code>Str:D</code></td>
    <td>Either "http" or "https".</td>
  </tr>
  <tr>
    <td><code>p6sgi.input</code></td>
    <td>Like <code>IO::Handle:_</code></td>
    <td>The input stream for reading the body of the request, if any.</td>
  </tr>
  <tr>
    <td><code>p6sgi.input.buffered</code></td>
    <td><code>Bool:D</code></td>
    <td>True if the input stream is buffered and seekable.</td>
  </tr>
  <tr>
    <td><code>p6sgi.errors</code></td>
    <td>Like <code>IO::Handle:D</code></td>
    <td>The error stream for logging.</td>
  </tr>
  <tr>
    <td><code>p6sgi.errors.buffered</code></td>
    <td><code>Bool:D</code></td>
    <td>True if the error stream is buffered.</td>
  </tr>
  <tr>
    <td><code>p6sgi.multithread</code></td>
    <td><code>Bool:D</code></td>
    <td>True if the app may be simultaneously invoked in another thread in the same process.</td>
  </tr>
  <tr>
    <td><code>p6sgi.multiprocess</code></td>
    <td><code>Bool:D</code></td>
    <td>True if the app may be simultaneously invoked in another process.</td>
  </tr>
  <tr>
    <td><code>p6sgi.run-once</code></td>
    <td><code>Bool:D</code></td>
    <td>True if the server expects the app to be invoked only once during the life of the process. This is not a guarantee.</td>
  </tr>
  <tr>
    <td><code>p6sgi.encoding</code></td>
    <td><code>Str:D</code></td>
    <td>Name of the encoding the server will use for any strings it is sent.</td>
  </tr>
  <tr>
    <td><code>p6sgix.output.sent</code></td>
    <td><code>Promise:D</code></td>
    <td>A vowed Promise that is kept by the server when the server is done processing the response. It will be broken if the server terminates processing early.</td>
  </tr>
</table>

In the environment, either `SCRIPT_NAME` or `PATH_INFO` must be set to a non-empty string. When `REQUEST_URI` is "/", the `PATH_INFO` SHOULD be "/" and `SCRIPT_NAME` SHOULD be the empty string. `SCRIPT_NAME` MUST NOT be set to "/".

For those familiar with Perl 5 PSGI, you may want to take care when working with some of these values. A few look very similar, but are subtly different.

The server or middleware or the application may store its own data in the environment as well. These keys MUST contain at least one dot, SHOULD be prefixed with a unique name.

The following prefixes are reserved for use by this standard:

  * `p6sgi.` is for P6SGI core standard environment.

  * `p6sgix.` is for P6SGI standard extensions to the environment.

### 2.0.2 The Input Stream

The input stream is set in the `p6sgi.input` key of the environment. The server MUST provide an object that implements the subset of the methods of [IO::Handle](IO::Handle) described here. It MAY provide an [IO::Handle](IO::Handle).

The input stream object provided by the server MUST provide the following methods:

  * read

        method read(Int:D $bytes) returns Blob { ... }

    This method MUST be available. This method is given the number of bytes to read from the input stream and returns a [Blob](Blob) containing up to that many bytes or a Blob type object if the stream has come to an end.

  * seek

        method seek(Int:D $offset, Int:D $whence where 0 >= * >= 2) returns Bool { ... }

    This method MAY be provided in all cases, but MUST be provided if `p6sgi.input.buffered` is set in the environment. Calling this moves the read cursor to byte position `$offset` relative to `$whence`, which is one of the following integers:

      * `0`: Seek from the start of the file.

      * `1`: Seek from the current read cursor position.

      * `2`: Seek from the end of the file.

    This method returns `True` on successful seek.

### 2.0.3 The Error Stream

The error stream MUST be given in the environment via `p6sgi.errors`. It is also an [IO::Handle](IO::Handle)-like object, used to log application errors. The server SHOULD write these errors to an appropriate log, console, etc. The error stream MAY be an [IO::Handle](IO::Handle).

The error stream MUST implement the following methods:

  * print

        multi method print(Str:D: $error) returns Bool:D { ... }
        multi method print(*@error) returns Bool:D { ... }

    Both multi variants MUST be provided. The slurpy version using `@error` will concatenate the stringified version of each value given for recording.

    Both variants return `True` on success.

  * flush

        method flush() returns Bool:D { ... }

    This method MUST be provided. It MAY be a no-op, particularly if `p6sgi.errors.buffered` is False. It SHOULD flush the error stream buffer. It returns `True` on success.

### 2.0.4 Application Response

A P6SGI application typically returns a [Promise](Promise). This Promise is kept with a [Capture](Capture) which contains 3 positional arguments: the status code, the headers, and the message body, respectively.

  * The status code is returned as an integer matching one of the standard HTTP status codes (e.g., 200 for success, 500 for error, 404 for not found, etc.).

  * The headers are returned as a List of Pairs mapping header names to header values.

  * The message body is typically returned as a [Supply](Supply) that emits zero or more [Str](Str) and [Blob](Blob) objects that are encoded, if necessary, and concatenated together to form the finished message body.

Here's an example of such a typical application:

    sub app(%env) {
        Promise.start({
            200, [ Content-Type => 'text/plain' ], Supply.from-list([ 'Hello World' ])
        });
    }

Aside from the typical response, applications are permitted to return any part of the response with a different type of object so long as that object provides a coercion to the required type. Here is another application that is functionally equivalent to the typical example just given:

    sub app(%env) {
        Supply.on-demand(-> $s {
            $s.emit([ 200, [ Content-Type => 'text/plain' ], [ 'Hello World' ]);
            $s.done;
        });
    }

Calling `Promise` on the returned object returns a Promise that is kept with the required Capture. The first two elements are what are normally expected, but the third is just a list. A [List](List), however, coerces to Supply as required.

The server SHOULD NOT assume that the Promise will always be kept and SHOULD handle a broken Promise as appropriate. The server SHOULD assume the Promise has been vowed a MUST NOT try to keep or break the Promise itself.

Each [Pair](Pair) in the list of headers maps a header name to a header value. The application may return the same header name multiple times. The order of multiple headers with the same name SHOULD be preserved.

If the application is missing headers that are required for the Status Code given or provides headers that are forbidden, the application server SHOULD treat that as a server error.

The server SHOULD examine the `Content-Type` header for the `charset` setting. This SHOULD be used to aid in encoding any [Str](Str) encountered when processing the Message Body. If the application does not provide a `charset`, the server MAY choose to add this header itself using the encoding provided in `p6sgi.encoding` in the environment.

The server SHOULD examine the `Content-Length` header, if given. It MAY choose to stop consuming the Message Body once the number of bytes given has been read. It SHOULD guarantee that the body length is the same as described in the `Content-Length`.

Unless the status code is one that is not permitted to have a message body, the application server MUST tap the Supply and process each emitted [Blob](Blob) or [Str](Str), until the the either the Supply is done or the server decides to quit tapping the stream for some reason.

The application server SHOULD continue processing emitted values until the Supply is done or until `Content-Length` bytes have been emitted. The server MAY stop tapping the Supply for various other reasons as well, such as timeouts or because the client has closed the socket, etc.

If the Supply is quit instead of being done, the server SHOULD attempt to handle the error as appropriate.

### 2.0.5 Encoding

It is up to the server how to handle encoded characters given by the application within the headers.

Within the body, however, any [Str](Str) emitted from the [Supply](Supply) MUST be encoded. If the application has specified a `charset` with the [Content-Type](Content-Type) header, the server SHOULD honor that character encoding. If none is given or the server does not honor the [Content-Type](Content-Type) header, it MUST encode any [Str](Str) with the encoding named in `psgi.encoding`.

Any [Blob](Blob) encountered in the body SHOULD be sent on as is, treating the data as plain binary.

2.1 Layer 1: Middleware
-----------------------

P6SGI middleware is a P6SGI application that wraps another P6SGI application. Middleware is used to perform any kind of pre-processing, post-processing, or side-effects that might be added onto an application. Possible uses include logging, encoding, validation, security, debugging, routing, interface adaptation, and header manipulation.

For example, in the following snippet `&mw` is a simple middleware application that adds a custom header:

    my &app = sub (%env) {
        Promise.start({
            200,
            [ Content-Type => 'text/plain' ],
            Supply.from-list([ 'Hello World' ])
        });
    }

    my &mw = sub (%env) {
        Promise.start({
            my @res = callsame.result;
            @res[1].push: (X-P6SGI-Used => 'True');
            @res;
        });
    };

    &app.wrap(&mw);

**Note:** For those familiar with PSGI and Plack should take careful notice that Perl 6 `wrap` has the invocant and argument swapped from the way Plack::Middlware operates. In P6SGI, the `wrap` method is always called on the *app* not the *middleware*.

### 2.1.0 Middleware Application

The way middleware is applied to an application varies. There are two basic mechanisms that may be used: the `wrap` method and the closure method. This is Perl, so there are likely other methods that are possible (since this is Perl 6, some might not be fully implemented yet).

#### 2.1.0.0 Wrap Method

This is the method demonstrated in the example above. Perl 6 provides a handy `wrap` method which may be used to apply another subroutine as an aspect of the subroutine being wrapped. In this case, the original application may be called using `callsame` or `callwith`.

2.1.0.1 Closure Method
----------------------

This method resembles that which would normally be used in PSGI, which is to define the middleware using a closure that wraps the application.

    my &mw = sub (%env) {
        Promise.start({
            my @res = app(%env).result;
            @res[1].push: (X-P6SGI-Used => 'True');
            @res;
        });
    };
    &app = &mw;

This example is functionality identical to the previous example.

### 2.1.1 Environment

Middleware applications SHOULD pass on the complete environment, only modifying the bits required to perform their purpose. Middlware applications MAY add new keys to the environment as a side-effect. These additional keys MUST contain a period and SHOULD use a unique namespace.

### 2.1.2 The Input Stream

Middleware applications reading the input stream SHOULD seek back to the beginning of the stream if it reads from the input stream.

### 2.1.3 The Error Stream

See section 2.2.3.

### 2.1.4 Application Response

As with an application, middleware MUST return a valid P6SGI response to the server.

### 2.1.5 Encoding

All the encoding issues in 2.2.5 need to be considered.

2.2 Layer 2: Application
------------------------

A P6SGI application is a Perl 6 routine that receives a P6SGI environment and responds to it by returning a response.

A simple Hello World P6SGI application may be implemented as follows:

    sub app(%env) {
        Promise.start({
            200, [ Content-Type => 'text/plain' ], [ 'Hello World' ]
        });
    }

### 2.2.0 Defining an Application

The way an application is defined and used by a P6SGI server may vary by server. The specification does not tell servers how to locate an application to run it, so you will need to see the server's documentation for a description of how to do that.

Typically, however, the application is defined in a script file that defines the application subroutine as the final statement in the file (or includes a reference to the application as the final line of the file).

For example, such a file might look like this:

    use v6;
    use MyApp;
    use MyApp::Middleware;
    sub app(%env) {
        my $app = MayApp.new;
        my @body = $app.run;

        200, [ Content-Type => 'text/plain' ], @body.item
    }
    &app.wrap(&my-middleware);
    &app;

In this example, we load some libraries from our imaginary main application, we define a simple P6SGI app, we apply some middleware (presumably exported from `MyApp::Middleware`), and then end with the reference to our application. This is the typical method by which an application server will load an application.

It is recommended that such files identify themselves with the suffix .p6w when a file suffix is useful.

### 2.2.1 The Environment

The one and only argument passed to the application is an [Associative](Associative) containing the environment. The environment variables that MUST be set are defined in section 2.0.1. Additional variables are probably defined by your application server, so please see its documentation for details.

The application MAY store additional values in the environment as it sees fit. This allows the application to communicate with a server or middleware or just to store information useful for the duration of the request. If the application modifies the environment, the variables set MUST contain a period and SHOULD start with a unique name that is not `p6sgi.` or `p6sgix.` as these are reserved.

### 2.2.2 The Input Stream

During a POST, PUT, or other operation, the client may send along a message body to your application. The application MAY choose to read the body using the input stream provided in the `p6sgi.input` key of the environment.

This is an [IO::Handle](IO::Handle)-like object, but might not be an IO::Handle. The application SHOULD NOT check what kind of object it is and just use the object's `read` and `seek` methods as needed. These are defined in more detail in section 2.0.2.

### 2.2.3 The Error Stream

The application server is required to provide a [p6sgi.errors](p6sgi.errors) variable in the environment with an [IO::Handle](IO::Handle)-like object capable of logging application errors. The application MAY choose to log errors here (or it MAY choose to log them wherever else it likes).

As with the input stream, the server is not required to provide an IO::Handle and the application SHOULD NOT check what kind of object it is, but just use the `print` and `flush` methods as defined in section 2.0.3.

### 2.2.4 Application Response

The application MUST return a valid P6SGI response to the server.

A trivial P6SGI application could be implemented like this:

    sub app(%env) {
        Promise.start({
            200,
            [ Content-Type => 'text/plain' ],
            [ "Hello World" ],
        });
    }

In detail, an application MUST return a [Promise](Promise) or an object that may coerce into a Promise (i.e., it has a `Promise` method that takes no arguments and returns a Promise object). This Promise MUST be kept with a Capture or object that coerces into a Capture (e.g., a [List](List) or an [Array](Array)). It MUST contain 3 positional arguments, which are, respectively, the status code, the list of headers, and the message body. These are each defined as follows:

  * The status code MUST be an [Int](Int) or object that coerces to an Int. It MUST be a valid HTTP status code.

  * The headers MUST be a [List](List) of [Pair](Pair)s naming the headers to the application intends to return. The application MAY return the same header name multiple times.

  * The message body MUST be a [Supply](Supply) that emits [Str](Str) and [Blob](Blob) objects or an object that coerces into such a Supply (e.g., a List or an Array).

For example, here is another example that demonstrates the flexibility possible in the application response:

    sub app(%env) {
        Promise.start({
            my $n = %env<QUERY_STRING>.Int;
            200,
            [ Content-Type => 'text/plain' ],
            Supply.on-demand(-> $content {
                my $acc = 1.FatRat;
                for 1..$n {
                    $content.emit("{$acc *= $n}\n");
                }
                $content.done;
            });
        });
    }

This application will print out all the values of factorial from 1 to N where N is given as the query string. The header is returned immediately, but the lines of the body are returned as the values of factorial are calculated.

### 2.2.5 Encoding

When sending the message body to the server, the application SHOULD prefer to use [Blob](Blob) objects. This allows the application to fully control the encoding of any text being sent.

The application MAY use [Str](Str), but this puts the server in charge of encoding the response. The server is only required to encode the data according to the encoding specified in the `p6sgi.encoding` key of the environment. Application servers are recommended to examine the `charset` of the Content-Type header returned by the application, but are not required to do so.

Applications SHOULD avoid characters that require encoding in HTTP headers.

Changes
=======

0.4.Draft
---------

  * Cutting back on some more verbose or unnecessary statements in the standard, trying to stick with just what is important and nothing more.

  * The application response has been completely restructured in a form that is both easy on applications and easy on middleware, mainly taking advantage of the fact that a List easily coerces into a Supply.

  * Eliminating the P6SGI compilation unit again as it is no longer necessary.

0.3.Draft
---------

  * Splitting the standard formally into layers: Application, Server, and Middleware.

  * Bringing back the legacy standards and bringing back the variety of standard response forms.

  * Middleware is given a higher priority in this revision and more explanation.

  * Adding the P6SGI compiliation unit to provide basic tools that allow middleware and possibly servers to easily process all standard response forms.

  * Section numbering has been added.

  * Added the Changes section.

  * Use `p6sgi.` prefixes in the environment rather than `psgi.`

0.2.Draft
---------

This second revision eliminates the legacy standard and requires that all P6SGI responses be returned as a [Promise](Promise). The goal is to try and gain some uniformity in the responses the server must deal with.

0.1.Draft
---------

This is the first published version. It was heavily influenced by PSGI and included interfaces based on the standard, deferred, and streaming responses of PSGI. Instead of callbacks, however, it used [Promise](Promise) to handle deferred responses and [Channel](Channel) to handle streaming. It mentioned middleware in passing.
