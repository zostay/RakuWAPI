NAME
====

P6SGI - Perl 6 Web Server Gateway Interface Specification

STATUS
======

This is a Proposed Draft.

Version 0.3.Draft

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

This document is strongly related to the PSGI pecification for Perl 5. Within a Perl 6 environment, it is acceptable to refer to this standard as "PSGI" with the "6" in "P6SGI" being implied. However, for clarity, P6SGI and PSGI from Perl 5 are different. This is possible because Perl 6 provides a number of built-in tools, e.g., reactive and concurrent programming tools, that simplify several aspects of this specification.

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

This aspect of the specification is deliberately vague and left up to the implementation. No requirements are made here.

It is recommended, however, that the server be able to load applications found in P6SGI script files. These are Perl 6 code files that end with the definition of a block to be used as the application routine. For example:

    use v6;
    sub app(%env) { 200, [ Content-Type => 'text/plain' ], [ 'Hello World!' ] }

This specification suggests adopting a file name suffix of .p6w (Perl 6 Web application files) to identify these files when an extension is appropriate.

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
    <td>C<< Str:D where *.chars > 0 >></td>
    <td>The HTTP request method, such as "GET" or "POST".</td>
  </tr>
  <tr>
    <td><code>SCRIPT_NAME</code></td>
    <td>C<< Str:D where any('', m{ ^ "/" }) >></td>
    <td>This is the initial prtion of the URL path that refers to the application.</td>
  </tr>
  <tr>
    <td><code>PATH_INFO</code></td>
    <td>C<< Str:D where any('', m{ ^ "/" }) >></td>
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
    <td>C<< Str:D where *.chars > 0 >></td>
    <td>This is the server name of the web server.</td>
  </tr>
  <tr>
    <td><code>SERVER_PORT</code></td>
    <td>C<< Int:D where * > 0 >></td>
    <td>This is the server port of the web server.</td>
  </tr>
  <tr>
    <td><code>SERVER_PROTOCOL</code></td>
    <td>C<< Str:D where *.chars > 0 >></td>
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

For those familiar with Perl 5 PSGI, you may want to take care when working with some of these values. A few look very similar, but are subtly different. For example, the setting called "psgix.input.buffered" in that standard is called "p6sgi.input.buffered" here and is not considered an extension. A server MAY choose to supply all of the PSGI equivalents as well and MUST if it wishes to provide PSGI backwards-compatibility.

The server or the application may store its own data in the environment as well. These keys MUST contain at least one dot, SHOULD be prefixed uniquely. The server MUST allow the application and middleware to store keys here and MAY choose to enforce the namespacing requirements in the object implementing the environment.

The following prefixes are reserved for use by this standard:

  * `p6sgi.` is for P6SGI core standard environment.

  * `p6sgix.` is for P6SGI standard extensions to the environment.

  * `psgi.` is for PSGI legacy standard environment.

  * `psgix.` is for PSGI legacy extensions to the environment.

### 2.0.2 The Input Stream

The input stream is set in the `p6sgi.input` key of the environment. The server MUST provide an object that implements a subset of the methods of [IO::Handle](IO::Handle). It MAY provide an [IO::Handle](IO::Handle).

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

P6SGI applications may respond to the environment in a variety of forms. A P6SGI server MUST be able to process all of the forms described in this specification.

As supporting a variety of response forms could be an obstacle to application server and, more importantly, middleware development, the P6SGI standard ships with a small compilation unit to help. It contains middleware applications able to convert these various forms into the form that is most flexible. This way an application server or middleware only has to suport one form.

The form an application response takes may vary in any number of ways. The way the standard forms may vary, those described by this specification, can be described in four or five components. To help understand what is possible, let us examine each of these components: wrapper, container, status code, headers, and body.

  * **Wrapper Component**. The wrapper component is the only optional part. It describes how the container component is delivered with the remaining parts. For example, an application may return a [Promise](Promise) that is kept with the container component or it may be omitted and the container returned directly by the application.

  * **Container Component**. The container component may be returned directly or may be returned within a wrapper component. It supplies the remaining three parts: status code, headers, and body. For example, a 3-element [Positional](Positional) is the container component with the elements referring to the status code, headers, and body, respectively.

  * **Status Code Component**. The status code component declares the HTTP status code the application is returning. For example, the status code is returned as an integer for status codes, like 200.

  * **Header Component**. The header component defines the headers the application intens to return to the client. For example, the header component is typically returned as a [List](List) of [Pair](Pair)s, with each key naming a header and each value being the value to set for that header.

  * **Body Component**. The body component defines the content of the message body. For example, the body component may be returned as a [Supply](Supply) that emits a series of [Str](Str)s and [Blob](Blob)s.

These components may vary independent of one another. For example, the body component might be returned as [Supply](Supply) or as an iterable list of [Str](Str)s and [Blob](Blob)s instead and the body may be returned by a container directly or a container kept by a [Promise](Promise). Furthermore, framework and application developers may wish to experiment with variations not described here. This is permitted, but such variations SHOULD be easy to distinguish from the standard forms and SHOULD also be easy to distinguish from each other. Such extensions can be universally supported by providing middleware to convert these response forms into the standard forms supported by all P6SGI servers and middleware.

#### 2.0.4.0 Wrapper Components

The wrapper component is an optional component wrapping the container component. The wrapper component determines the overall protocol to be used when handling the response. It may also be that the wrapper requires its own particular kind of container to work.

##### 2.0.4.0.0 No Wrapper

Rather than using a wrapper, the application MAY respond with the container directly.

The application should assume that the response is the container directly if the response does not test as being any of the standard wrapper forms.

##### 2.0.4.0.1 Promise

When the application response is a Promise, the server SHOULD NOT assume that the Promise will always be kept and SHOULD handle a broken Promise as appropriate. The server SHOULD assume the Promise has been vowed a MUST NOT try to keep or break the Promise itself.

The test to identify this wrapper component is:

    $response ~~ Promise

The mechanism for receiving the container is:

    $response.then({
        given $response.status {
            when Kept { $container = $response }
            default   { #{ handle error } }
        }
    });

##### 2.0.4.0.2 Callback (Legacy)

This is a PSGI legacy wrapper form and a server is NOT REQUIRED to support it.

When the appliation resopnse is a [Callable](Callable), the legacy supporting server MUST call the returned code and pass in a single parameter, which is itself a callback. This second callback will be called by the application with the container component or part of the container component. (In this legacy form, the container is defined as part of the wrapper.)

If all three elements of the container are provided to the second callback, the response is complete. If, however, the application passes only two elements, the legacy supporting server MUST return a writer object, which will be used by the application to return the message body.

The test for this wrapper is:

    $response ~~ Callable

The code for acquiring the container from the response is similar to as follows:

    my $container-promise = Promise.new;
    sub server-callback (@app-response) {
        my @container = @app-response;
        if @container.elems == 2 {
            Promise.start({
                @container.push: $p.result
                $container-promise.keep(@container);
            });
            return class {
                has @.body;
                multi method write(Str $s) { @.body.push($s) }
                multi method write(Blob $b) { @.body.push($b) }
                method close() { $p.keep(@.body) }
            }.new;
        }
        else {
            $container-promise.keep(@container);
        }
    }

    $response.(&server-callback)
    @container = $container-promise.result;

#### 2.0.4.1 Container

This container component simply defines how the server retrieves the components. It may be returned directly by the application or wrapped in a wrapper component.

##### 2.0.4.1.1 Positional

Only a single container component form is defined here. The container is given as a [Positional](Positional) with exactly three elements.

The test for this is:

    $container ~~ Positional && $container.elems == 3

Extracting the other components is handled like so:

    ($status, $headers, $body) = $container.list;

#### 2.0.4.2 Status

The status code MUST map to an HTTP status code.

##### 2.0.4.2.1 Int

The application is required to set this to a valid HTTP status code as an integer. The application server MAY attempt to verify the validity of the status code and that the rest of the response is sane according to the HTTP standards.

The test for this component form is:

    $status ~~ Int

#### 2.0.4.3 Header

The header component declares the HTTP headers the application intends to return. It may also define the order the application prefers the headers be returned in.

##### 2.0.4.3.0 List of Pairs

The headers are returned as a [List](List) of [Pair](Pair)s, each Pair maps a header name to a header value.

The server SHOULD attempt to pass on all given headers. The application server MAY perform any validation necessary and MAY deal with errors as appropriate. Any custom headers SHOULD be honored, if possible and security allows, etc. The order of multiple headers with the same name, relative to one another, MUST be preserved.

If the application is missing headers that are required for the Status Code given or provides headers that are forbidden, the application server SHOULD treat that as a server error.

The server SHOULD examine the [Content-Type](Content-Type) header for the `charset` setting. This SHOULD be used to aid in encoding any [Str](Str) encountered when processing the Message Body. If the application does not provide a `charset`, the server MAY choose to add this header itself using the encoding provided in `p6sgi.encoding` in the environment.

The server SHOULD examine the [Content-Length](Content-Length) header, if given. It MAY choose to stop consuming the Message Body once the number of bytes given has been read.

The test for this component is:

    $header ~~ List && $header.all ~~ Pair

#### 2.0.4.4 Message Body

The message body may be given in one of the following two forms.

##### 2.0.4.4.0 Supply of Str and Blob

The best and most flexible form, but not necessarily the most straightforward, is to use a [Supply](Supply). This [Supply](Supply) will emit [Blob](Blob) and [Str](Str) objects.

The server SHOULD NOT concern itself with whether the [Supply](Supply) given is on demand or live. The application server MUST tap the Supply and process each emitted [Blob](Blob) or [Str](Str), until the the either the Supply is done or the server decides to quit tapping the stream for some reason.

The application server SHOULD continue processing emitted values until the Supply is done or until [Content-Length](Content-Length) bytes have been emitted. The server MAY stop tapping the Supply for various other reasons as well, such as timeouts or because the client has closed the socket, etc.

If the Supply is quit instead of being done, the server SHOULD attempt to handle the error as appropriate.

The server SHOULD attempt to pass on the message body as given, unless the request is one identified by the relevant HTTP standards as not having a body. If the applicaiton provides a non-empty message body, the application server SHOULD treat that as an error.

The test for this component is:

    $body ~~ Supply

##### 2.0.4.4.1 Iterable of Str and Blob

This variation may be treated the same as the [Supply](Supply) form by using `from-list` to generate a Supply from this List. All the specifications for such bodies apply here.

The test for this form is:

    $body ~~ Iterable

### 2.0.5 Encoding

It is up to the server how to handle encoded characters given by the application within the headers.

Within the body, however, any [Str](Str) emitted from the [Supply](Supply) MUST be encoded. If the application has specified a `charset` with the [Content-Type](Content-Type) header, the server SHOULD honor that character encoding. If none is given or the server does not honor the [Content-Type](Content-Type) header, it MUST encode any [Str](Str) with the encoding named in `psgi.encoding`.

Any [Blob](Blob) encountered in the body SHOULD be sent on as is, treating the data as plain binary.

2.1 Layer 1: Middleware
-----------------------

P6SGI middleware is a P6SGI application that wraps another P6SGI application. In some ways it may act as a server, in other ways it may act as an application. Middleware is used to perform any kind of pre-processing, post-processing, or side-effects that might be added onto an application. Possible uses include logging, encoding, validation, security, debugging, routing, interface adaptation, and header manipulation.

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

As with servers, middleware MUST support the standard application response forms. As supporting all these standard forms would be onerous to most middleware developers, the P6SGI standard ships with a small compilation unit that may be used to assist in this support.

### 2.1.0 Middleware Application

The way middleware is applied to an application varies. There are two basic mechanisms that may be used: the `wrap` method and the closure method.

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

As with an application, middleware MUST return a valid P6SGI response to the server. Middleware developers SHOULD write design their middleware to return the best, most flexible form available. This is the form that returns a [Promise](Promise) wrapper around a [Positional](Positional) container containing an [Int](Int) status, [List](List) of [Pair](Pair)s header, and a [Supply](Supply) of [Str](Str) and [Blob](Blob) message body.

See 2.2.4 for information on the response forms.

### 2.1.5 Encoding

All the encoding issues in 2.2.5 need to be considered.

In addition, the middleware application SHOULD pass through the message body unchanged when it does not need to work with it. If the middlware application does need to work with the message body, it SHOULD NOT modify the encoding of the body unless necessary. Whenever possible, it SHOULD maintain [Str](Str) as [Str](Str) and [Blob](Blob) as [Blob](Blob).

2.2 Layer 2: Application
------------------------

A P6SGI application is a Perl 6 routine that receives a P6SGI environment and responds to it by returning a response. A P6SGI application may return a response in a number of various forms, one of which is considered the best form.

A simple Hello World P6SGI application may be implemented as follows:

    sub app(%env) {
        200, [ Content-Type => 'text/plain' ], [ 'Hello World' ]
    }

However, the best form for Hello World P6SGI application for the same might be done like this:

    sub app(%env) {
        Promise.start({
            200,
            [ Content-Type => 'text/plain' ],
            Supply.from-list([ 'Hello World' ])
        })
    }

All P6SGI middleware and servers are required to support all standard forms, but the best form is the easiest for servers and middleware to work with and generally performs the best.

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

Here we load some libraries from our main application, we define a simple P6SGI app, we apply some middleware, and then end with the reference to our application. This is the typical method by which an application server will load an application.

It is recommended that such files identify themselves with the suffix .p6w when a file suffix is useful.

### 2.2.1 The Environment

The one and only argument passed to the application is an [Associative](Associative) containing the environment. The environment variables that MUST be set are defined in section 2.0.1. Additional variables are probably defined by your application server, so please see its documentation for details.

The application MAY store additional values in the environment as it sees fit. This allows the application to communicate with a server or middleware or just to store information useful for the duration of the request. If the application modifies the environment, the variables set MUST contain a period and SHOULD start with a unique name that is not one of: `psgi.`, `psgix.`, `p6sgi.`, or `p6sgix.` as these are reserved.

### 2.2.2 The Input Stream

During a POST, PUT, or other operation, the client may send along a message body to your application. The application MAY choose to read the body using the input stream provided in the `p6sgi.input` key of the environment.

This is an [IO::Handle](IO::Handle)-like object, but might not be an IO::Handle. The application SHOULD NOT check what kind of object it is and just use the object's `read` and `seek` methods as needed. These are defined in more detail in section 2.0.2.

### 2.2.3 The Error Stream

The application server is required to provide a [p6sgi.errors](p6sgi.errors) key with an [IO::Handle](IO::Handle)-like object capable of logging application errors. The application MAY choose to log errors here (or it MAY choose to log them wherever else it likes).

As with the input stream, the server is not required to provide an IO::Handle and the application SHOULD NOT check what kind of object it is, but just use the `print` and `flush` methods as defined in section 2.0.3.

### 2.2.4 Application Response

The application MUST return a valid P6SGI response to the server. Any serious application SHOULD prefer to use the best, most flexible response form.

The best response form is a [Promise](Promise) that is kept with a 3-element [Positional](Positional) with the following indexes, respectively:

  * **Status Code**. This is a standard HTTP status code.

  * **Message Headers**. This is a [List](List) of [Pair](Pair)s naming the headers the application wishes to put into the response.

  * **Message Body**. This is a [Supply](Supply) which emits [Blob](Blob) and [Str](Str) objects to be sent as the content of the response.

A trivial P6SGI application could be implemented like this in this best form:

    sub app(%env) {
        Promise.start({
            200,
            [ Content-Type => 'text/plain' ],
            Supply.from-list([ "Hello World" ]),
        });
    }

However, to display the power of this form, here is a more interesting version:

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

In addition to this form, the application MAY return the response in other forms. These variations are described in the following sections. These other forms are provided for convenience and legacy support.

#### 2.2.4.0 Direct Response

Rather than returning a [Promise](Promise) that is kept with a [Positional](Positional), a P6SGI application MAY return that [Positional](Positional) directly. The rest of the form is the same.

#### 2.2.4.1 Message Body as a List

A second variation that an application MAY provide is a message body as a [List](List) of [Str](Str) and [Blob](Blob) rather than as a [Supply](Supply). This is slightly shorter than using a [Supply](Supply) and is provided for convenience. Actually, any [Iterable](Iterable) object is supported.

### 2.2.5 Encoding

When sending the message body to the server, the application SHOULD prefer to use [Blob](Blob) objects. This allows the application to fully control the encoding of any text being sent.

The application MAY use [Str](Str), but this puts the server in charge of encoding the response. The server is only required to encode the data according to the encoding specified in the `p6sgi.encoding` key of the environment. Application servers are recommended to examine the `charset` of the Content-Type header returned by the application, but are not required to do so.

Applications SHOULD avoid characters that require encoding in HTTP headers.

Changes
=======

0.3.Draft
---------

    * Splitting the standard formally into layers: Application, Server, and Middleware.
    * Bringing back the legacy standards and bringing back the variety of standard response forms.
    * Middleware is given a higher priority in this revision and more explanation.
    * Adding the P6SGI compiliation unit to provide basic tools that allow middleware and possibly servers to easily process all standard response forms.
    * Section numbering has been added.
    * Added the Changes section.
    * Use <code>p6sgi.</code> prefixes in the environment rather than <code>psgi.</code>

0.2.Draft
---------

This second revision eliminates the legacy standard and requires that all P6SGI responses be returned as a [Promise](Promise). The goal is to try and gain some uniformity in the responses the server must deal with.

0.1.Draft
---------

This is the first published version. It was heavily influenced by PSGI and included interfaces based on the standard, deferred, and streaming responses of PSGI. Instead of callbacks, however, it used [Promise](Promise) to handle deferred responses and [Channel](Channel) to handle streaming. It mentioned middleware in passing.
