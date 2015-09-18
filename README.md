NAME
====

P6SGI - Perl 6 Web Server Gateway Interface Specification

STATUS
======

This is a Proposed Draft.

Version 0.5.Draft

0 INTRODUCTION
==============

This document standardizes the interface to be implemented by web application developers in Perl 6. It provides a standard protocol by which application servers may communicate with web applications.

This standard has the following goals:

  * Standardize the interface between server and application so that web developers may focus on application development rather than the nuances of supporting each of several server platforms.

  * Keep the interface simple so that a web application or middleware requires no additional tools or libraries other than what exists in a standard Perl 6 environment, no module installations are required.

  * Keep the interface simple so that servers and middleware are simple to implement.

  * Allow the interface to flexible enough to accomodate a variety of common use-cases and simple optimzations.

  * Provide flexibility so that unanticipated use-cases may be implemented and so that the interface may be extended by servers wishing to do so.

Aside from that is the underlying assumption that this is a simple interface and ought to at least somewhat resemble work in the standards it is derived from, including [Rack](http://www.rubydoc.info/github/rack/rack/master/file/SPEC), [WSGI](https://www.python.org/dev/peps/pep-0333/), [PSGI](https://metacpan.com/pod/PSGI), [CGI](http://www.w3.org/CGI/), and others.

1 TERMINOLOGY
=============

A P6SGI application is a Perl 6 routine that expects to receive an environment from an *application server* and returns a response each time it is called by the server.

A Web Server is an application that processes requests and responses according to the HTTP or related protocol.

The origin is the external entity that makes a given request and/or expects a response from the application server. This can be thought of generically as a web browser, bot, or other user agent.

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

A P6SGI application server typically implements some variant of web service. This typically means implementing an HTTP/1.x protocol service or a related protocol such as CGI, FastCGI, SCGI, etc. An application server also manages the application lifecycle and executes the application, providing it with a complete environment, and processing the response from the application to determine how to respond to the origin.

An application server SHOULD strive to be as flexible as possible to allow as many unusual interactions, subprotocols, and upgrade protocols to be implemented as possible within the connection.

### 2.0.0 Locating Applications

The server MUST be able to find applications.

It SHOULD be able to load applications found in P6SGI script files. These are Perl 6 code files that end with the definition of a block to be used as the application routine. For example:

```perl6
    use v6;
    sub app(%env) {
        start {
            200, [ Content-Type => 'text/plain' ], [ 'Hello World!' ]
        }
    }
```

These files MAY have a .p6w suffix, but this is not at all required.

### 2.0.1 The Environment

The environment MUST be an [Associative](http://doc.perl6.org/type/Associative). The keys of this map are mostly derived the old Common Gateway Interface (CGI) as well as a number of additional P6SGI-specific values. The application server MUST provide each key as the type given. All variables given in the table below MUST be supported, except for those with the `p6sgix.` prefix.

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
    <td>This is the remainder of the request URL path within the application. This value SHOULD be URI decoded by the application server according to <a href="http://www.ietf.org/rfc/rfc3875">RFC 3875</a></td>
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
    <td>The remaining request headers are placed here. The names are prefixed with <code>HTTP_</code>, in ALL CAPS with the hyphens ("-") turned to underscores ("_"). Multiple incoming headers with the same name should be joined with a comma (", ") as described in <a href="http://www.ietf.org/rfc/rfc2616">RFC 2616</a>. The <code>HTTP_CONTENT_LENGTH</code> and <code>HTTP_CONTENT_TYPE</code> headers MUST NOT be set.</td>
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
    <td><code>Supply:D</code></td>
    <td>The input stream for reading the body of the request, if any.</td>
  </tr>
  <tr>
    <td><code>p6sgi.errors</code></td>
    <td><code>Supply:D</code></td>
    <td>The error stream for logging.</td>
  </tr>
  <tr>
    <td><code>p6sgi.ready</code></td>
    <td><code>Promise:D</code></td>
    <td>This is a vowed Promise that MUST be kept by the server as soon as the server has tapped the application's output Supply and is ready to receive emitted messages. The value of the kept Promise is irrelevent. The server SHOULD NOT break this Promise.</td>
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
    <td><code>p6sgi.body.encoding</code></td>
    <td><code>Str:D</code></td>
    <td>Name of the encoding the server will use for any strings it is sent.</td>
  </tr>
</table>

In the environment, either `SCRIPT_NAME` or `PATH_INFO` must be set to a non-empty string. When `REQUEST_URI` is "/", the `PATH_INFO` SHOULD be "/" and `SCRIPT_NAME` SHOULD be the empty string. `SCRIPT_NAME` MUST NOT be set to "/".

For those familiar with Perl 5 PSGI, you may want to take care when working with some of these values. A few look very similar, but are subtly different.

The server or middleware or the application may store its own data in the environment as well. These keys MUST contain at least one dot, SHOULD be prefixed with a unique name.

The following prefixes are reserved for use by this standard:

  * `p6sgi.` is for P6SGI core standard environment.

  * `p6sgix.` is for P6SGI standard extensions to the environment.

### 2.0.2 The Input Stream

The input stream is set in the `p6sgi.input` key of the environment. The server MUST provide a [Supply](http://doc.perl6.org/type/Supply) that emits [Blob](http://doc.perl6.org/type/Blob) objects containing the content of the request payload, if any. When the message payload is completely received, the server MUST call `done` on the Supply. If there is an error processing the request payload, such as an early termination of the body by the client, the server MUST call `quit` on the Supply with an appropriate exception.

The `p6sgi.input` Supply MUST either be an on-demand Supply or the server MUST not begin emitting values to the Supply until after the `p6sgi.ready` [Promise](http://doc.perl6.org/type/Promise) has been kept.

### 2.0.3 The Error Stream

The error stream MUST be given in the environment via `p6sgi.errors`. This MUST be a [Supply](http://doc.perl6.org/type/Supply) the server provides emitting errors. The application MAY call `emit` on the Supply zero or more times, passing any object that may be stringified. The server SHOULD write these log entries to a suitable log file or to STDERR or wherever appropriate. If written to a typical file handle, it should automatically append a newline to each emitted message.

### 2.0.4 Application Response

A P6SGI application typically returns a [Promise](http://doc.perl6.org/type/Promise). This Promise is kept with a [Capture](http://doc.perl6.org/type/Capture) which contains 3 positional arguments: the status code, the headers, and the message body, respectively.

  * The status code is returned as an integer matching one of the standard HTTP status codes (e.g., 200 for success, 500 for error, 404 for not found, etc.).

  * The headers are returned as a List of Pairs mapping header names to header values.

  * The response payload is returned as a [Supply](http://doc.perl6.org/type/Supply) that emits zero or more objects. The server MUST handle any [Cool](http://doc.perl6.org/type/Cool) or [Blob](http://doc.perl6.org/type/Blob) that are emitted as part of the message payload. In addition to Cool and Blob, servers may also received [List](http://doc.perl6.org/type/List)s of [Pair](http://doc.perl6.org/type/Pair)s to allow applications to embed trailing headers, and [Associative](http://doc.perl6.org/type/Associative) objects containing protocol-specific messages and options.

Here's an example of such a typical application:

```perl6
    sub app(%env) {
        start {
            200, [ Content-Type => 'text/plain' ], Supply.from-list([ 'Hello World' ])
        };
    }
```

Aside from the typical response, applications are permitted to return any part of the response with a different type of object so long as that object provides a coercion to the required type. Here is another application that is functionally equivalent to the typical example just given:

```perl6
    sub app(%env) {
        Supply.on-demand(-> $s {
            $s.emit([ 200, [ Content-Type => 'text/plain' ], [ 'Hello World' ]);
            $s.done;
        });
    }
```

Calling `Promise` on the returned object returns a Promise that is kept with the required Capture. The first two elements are what are normally expected, but the third is just a list. A [List](http://doc.perl6.org/type/List), however, coerces to Supply as required.

The server SHOULD NOT assume that the Promise will always be kept and SHOULD handle a broken Promise as appropriate. The server SHOULD assume the Promise has been vowed a MUST NOT try to keep or break the Promise itself.

Each [Pair](http://doc.perl6.org/type/Pair) in the list of headers maps a header name to a header value. The application may return the same header name multiple times. The order of multiple headers with the same name SHOULD be preserved.

If the application is missing headers that are required for the Status Code given or provides headers that are forbidden, the application server SHOULD treat that as a server error.

The server SHOULD examine the `Content-Type` header for the `charset` setting. This SHOULD be used to aid in encoding any [Str](http://doc.perl6.org/type/Str) encountered when processing the Message Body. If the application does not provide a `charset`, the server MAY choose to add this header itself using the encoding provided in `p6sgi.body.encoding` in the environment.

The server SHOULD examine the `Content-Length` header, if given. It MAY choose to stop consuming the Message Body once the number of bytes given has been read. It SHOULD guarantee that the body length is the same as described in the `Content-Length`.

Unless the status code is one that is not permitted to have a message body, the application server MUST tap the Supply and process each emitted [Blob](http://doc.perl6.org/type/Blob) or [Cool](http://doc.perl6.org/type/Cool), until the the either the Supply is done or the server decides to quit tapping the stream for some reason.

The application server SHOULD continue processing emitted values until the Supply is done or until `Content-Length` bytes have been emitted. The server MAY stop tapping the Supply for various other reasons as well, such as timeouts or because the client has closed the socket, etc.

If the Supply is quit instead of being done, the server SHOULD attempt to handle the error as appropriate.

### 2.0.5 Payload and Encoding

It is up to the server how to handle encoded characters given by the application within the headers.

Within the body, however, any [Cool](http://doc.perl6.org/type/Cool) emitted from the [Supply](http://doc.perl6.org/type/Supply) MUST be stringified and then encoded. If the application has specified a `charset` with the `Content-Type` header, the server SHOULD honor that character encoding. If none is given or the server does not honor the `Content-Type` header, it MUST encode any stringified Cool with the encoding named in `psgi.encoding`.

Any [Blob](http://doc.perl6.org/type/Blob) encountered in the body SHOULD be sent on as is, treating the data as plain binary.

Any [List](http://doc.perl6.org/type/List) of [Pair](http://doc.perl6.org/type/Pair)s is treated as a trailing header. The details of how this works are protocol-specific.

Any [Associative](http://doc.perl6.org/type/Associative) defines a custom message which allows the application to communicate special protocol-specific messages through the server.

### 2.0.6 Application Lifecycle

A P6SGI application server processes requests from an origin, passes the processed request information to the application, waits for the application's response, and then returns the response to the origin. In the simplest example this means handling an HTTP roundtrip. It may also mean implementing a related protocol like CGI or FastCGI or SCGI or something else entirely.

In the modern web, an application may want to implement a variety of complex HTTP interactions. These use-cases are not described by the typical HTTP request-response roundtrip. For example, an application may implement a WebSocket API or an interactive Accept-Continue response or stream data to or from the origin. As such, application servers SHOULD make a best effort to be implemented in such a way as to make this variety applications possible.

The application server SHOULD pass control to the application as soon as the headers have been received and the environment can be constructed. The application server MAY continue processing the message body while the application server begins its work. The server SHOULD NOT emit the contents of the request payload via `p6sgi.input` yet. The server MUST NOT emit to `p6sgi.input` at this point unless the [Supply](http://doc.perl6.org/type/Supply) there is provided on-demand.

Once the application has returned the response headers and the response payload to the server. The server MUST tap the [Supply](http://doc.perl6.org/type/Supply) representing the response payload as soon as possible. Immediately after tapping the Supply, the application server MUST keep the [Promise](http://doc.perl6.org/type/Promise) (with no value) in `p6sgi.ready`. The application server SHOULD NOT break this Promise. Immediately after keeping the Promise in `p6sgi.ready`, the server SHOULD start emitting the contents of the request payload, if any, to `p6sgi.input`.

The server SHOULD return the application response headers back to the origin as soon as they are received. After which, the server SHOULD return each chunk emitted by the response body from the application as soon as possible.

2.1 Layer 1: Middleware
-----------------------

P6SGI middleware is a P6SGI application that wraps another P6SGI application. Middleware is used to perform any kind of pre-processing, post-processing, or side-effects that might be added onto an application. Possible uses include logging, encoding, validation, security, debugging, routing, interface adaptation, and header manipulation.

For example, in the following snippet `&mw` is a simple middleware application that adds a custom header:

```perl6
    my &app = sub (%env) {
        start {
            200,
            [ Content-Type => 'text/plain' ],
            Supply.from-list([ 'Hello World' ])
        };
    }

    my &mw = sub (%env) {
        callsame().then(-> $p {
            my @res = $p.result;
            @res[1].push: P6SGI-Used => 'True';
            @res;
        });
    };

    &app.wrap(&mw);
```

**Note:** For those familiar with PSGI and Plack should take careful notice that Perl 6 `wrap` has the invocant and argument swapped from the way Plack::Middlware operates. In P6SGI, the `wrap` method is always called on the *app* not the *middleware*.

### 2.1.0 Middleware Application

The way middleware is applied to an application varies. There are two basic mechanisms that may be used: the `wrap` method and the closure method. This is Perl, so there are likely other methods that are possible (since this is Perl 6, some might not be fully implemented yet).

#### 2.1.0.0 Wrap Method

This is the method demonstrated in the example above. Perl 6 provides a handy `wrap` method which may be used to apply another subroutine as an aspect of the subroutine being wrapped. In this case, the original application may be called using `callsame` or `callwith`.

#### 2.1.0.1 Closure Method

This method resembles that which would normally be used in PSGI, which is to define the middleware using a closure that wraps the application.

```perl6
    my &mw = sub (%env) {
        app(%env).then(-> $p {
            my @res = $p.result;
            @res[1].push: P6SGI-Used => 'True';
            @res;
        });
    };
    &app = &mw;
```

This example is functionality identical to the previous example.

### 2.1.1 Environment

Middleware applications SHOULD pass on the complete environment, only modifying the bits required to perform their purpose. Middlware applications MAY add new keys to the environment as a side-effect. These additional keys MUST contain a period and SHOULD use a unique namespace.

### 2.1.2 The Input Stream

An application server is required to provide the input stream as a [Supply](http://doc.perl6.org/type/Supply) emitting [Blob](http://doc.perl6.org/type/Blob)s. Middleware, however, MAY replace the Supply with one that emits anything that might be useful to the application or even remove it altogether.

The middleware MUST still terminate the payload in the Input Stream with a call to `done` and an abnormal termination with `quit`.

### 2.1.3 The Error Stream

See section 2.2.3.

### 2.1.4 Application Response

As with an application, middleware MUST return a valid P6SGI response to the server.

### 2.1.5 Payload and Encoding

All the encoding issues in 2.0.5 and 2.2.5 need to be considered.

Special care needs to be taken when middleware needs to process the application body. In such cases, the middleware MUST deal with the possibility of needing to encode the characters being supplied. In such cases, middleware MUST do its best to handle encoding as servers are required:

  * Any [Blob](http://doc.perl6.org/type/Blob) data SHOULD be passed through as-is.

  * Any non-Blob SHOULD be stringified using [Str](http://doc.perl6.org/type/Str) or the unary `~` prefix.

  * Middleware SHOULD examine the charset value of the Content-Type header and prefer that encoding.

  * If no charset is present or the middleware does not implementing charset handling, the middleware MUST encode using the value in `p6sgi.body.encoding`.

The application is permitted to emit any object as part of the response payload so long as some middleware maps those objects into the types the application server is required to support: [Cool](http://doc.perl6.org/type/Cool), [Blob](http://doc.perl6.org/type/Blob), [List](http://doc.perl6.org/type/List) of [Pairs](http://doc.perl6.org/type/Pairs), and [Associative](http://doc.perl6.org/type/Associative). The latter two must be appropriate for the protocol being communicated.

2.2 Layer 2: Application
------------------------

A P6SGI application is a Perl 6 routine that receives a P6SGI environment and responds to it by returning a response.

A simple Hello World P6SGI application may be implemented as follows:

```perl6
    sub app(%env) {
        start {
            200, [ Content-Type => 'text/plain' ], [ 'Hello World' ]
        };
    }
```

### 2.2.0 Defining an Application

The way an application is defined and used by a P6SGI server may vary by server. The specification does not tell servers how to locate an application to run it, so you will need to see the server's documentation for a description of how to do that.

Typically, however, the application is defined in a script file that defines the application subroutine as the final statement in the file (or includes a reference to the application as the final line of the file).

For example, such a file might look like this:

```perl6
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
```

In this example, we load some libraries from our imaginary main application, we define a simple P6SGI app, we apply some middleware (presumably exported from `MyApp::Middleware`), and then end with the reference to our application. This is the typical method by which an application server will load an application.

It is recommended that such files identify themselves with the suffix .p6w when a file suffix is useful.

### 2.2.1 The Environment

The one and only argument passed to the application is an [Associative](http://doc.perl6.org/type/Associative) containing the environment. The environment variables that MUST be set are defined in section 2.0.1. Additional variables are probably defined by your application server, so please see its documentation for details.

The application MAY store additional values in the environment as it sees fit. This allows the application to communicate with a server or middleware or just to store information useful for the duration of the request. If the application modifies the environment, the variables set MUST contain a period and SHOULD start with a unique name that is not `p6sgi.` or `p6sgix.` as these are reserved.

### 2.2.2 The Input Stream

During a POST, PUT, or other operation, the client may send along a request payload to your application. The application MAY choose to read the body using the input stream provided in the `p6sgi.input` key of the environment. This is a [Supply](http://doc.perl6.org/type/Supply), which may emit any kind of object. The server will provide a Supply that emits zero or more [Blob](http://doc.perl6.org/type/Blob)s, but the application middleware may map that information as required. It is expected that the application will be written with the kind of data it may receive in mind.

On normal termination of the payload, the Supply will finish with a `done` signal. On error, it will finish with a `quit`.

### 2.2.3 The Error Stream

The application server is required to provide a `p6sgi.errors` variable in the environment with a [Supply](http://doc.perl6.org/type/Supply) object. The application MAY emit any errors or messages here using any object that stringifies. The application SHOULD NOT terminate such messages with a newline as the server will do so if necessary.

### 2.2.4 Application Response

The application MUST return a valid P6SGI response to the server.

A trivial P6SGI application could be implemented like this:

```perl6
    sub app(%env) {
        start {
            200,
            [ Content-Type => 'text/plain' ],
            [ "Hello World" ],
        };
    }
```

In detail, an application MUST return a [Promise](http://doc.perl6.org/type/Promise) or an object that may coerce into a Promise (i.e., it has a `Promise` method that takes no arguments and returns a Promise object). This Promise MUST be kept with a Capture or object that coerces into a Capture (e.g., a [List](http://doc.perl6.org/type/List) or an [Array](http://doc.perl6.org/type/Array)). It MUST contain 3 positional arguments, which are, respectively, the status code, the list of headers, and the message body. These are each defined as follows:

  * The status code MUST be an [Int](http://doc.perl6.org/type/Int) or object that coerces to an Int. It MUST be a valid HTTP status code.

  * The headers MUST be a [List](http://doc.perl6.org/type/List) of [Pair](http://doc.perl6.org/type/Pair)s naming the headers to the application intends to return. The application MAY return the same header name multiple times.

  * The message body MUST be a [Supply](http://doc.perl6.org/type/Supply) that typically emits [Cool](http://doc.perl6.org/type/Cool) and [Blob](http://doc.perl6.org/type/Blob) and [List](http://doc.perl6.org/type/List) of [Pair](http://doc.perl6.org/type/Pair) and [Associative](http://doc.perl6.org/type/Associative) objects or an object that coerces into such a Supply (e.g., a List or an Array).

For example, here is another example that demonstrates the flexibility possible in the application response:

```perl6
    sub app(%env) {
        start {
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
        };
    }
```

This application will print out all the values of factorial from 1 to N where N is given as the query string. The header is returned immediately, but the lines of the body are returned as the values of factorial are calculated.

### 2.2.5 Payload and Encoding

The application may emit any object to the returned [Supply](http://doc.perl6.org/type/Supply) to be part of the response payload. It is expected, however, that either these objects will be mapped into the expectations of the application server by middleware or already be in such a form.

The server is expected to process the following emitted objects:

  * [Blob](http://doc.perl6.org/type/Blob). When sending the response payload to the server, the application SHOULD prefer to use Blob objects for the main data payload. This allows the application to fully control the encoding of any text being sent.

  * [Cool](http://doc.perl6.org/type/Cool). It is also possible for the application to use Cool instances, but this puts the server in charge of stringifying and encoding the response. The server is only required to encode the data according to the encoding specified in the `p6sgi.body.encoding` key of the environment. Application servers and middleware recommended to examine the `charset` of the Content-Type header returned by the application, but are not required to do so.

  * [List](http://doc.perl6.org/type/List) of [Pair](http://doc.perl6.org/type/Pair)s. Some response payloads may require an additional set of trailing headers. This allows for additional headers to be sent after the payload.

  * [Associative](http://doc.perl6.org/type/Associative). Some web protocols require custom options and messages. These are passed from application to server using Associative objects (usually a [Hash](http://doc.perl6.org/type/Hash)).

Applications SHOULD avoid characters that require encoding in HTTP headers.

3 Extensions
============

In addition to the standard specification, there are a number of extensions that servers or middleware MAY choose to implement. They are completely optional and applications and middleware SHOULD check for their presence before depending on them

3.0 Environment Extensions
--------------------------

These are extensions to the standard environment.

### 3.0.0 Header Done

The `p6sgix.header.done` environment variable, if provided, MUST be a vowed [Promise](http://doc.perl6.org/type/Promise). This Promise MUST be kept when the server is done sending or processing the response header. The Promise MUST be broken if the server is unable to or will not send the application provided headers. 

This is not an exhaustive list, but here are a few possible reasons why this Promise MAY be broken:

  * The headers are invalid and the application server will not send them.

  * An internal error occurred in the application server.

  * The client hungup the connection before the headers could be sent.

### 3.0.1 Body Done

The `p6sgix.body.done` environment variable, if provided, MUST be a vowed [Promise](http://doc.perl6.org/type/Promise). This Promise MUST be kept when the server is done sending or processing the response body. The Promise MUST be broken if the server is unable to or will not send the complete application body.

This is not an exhaustive list, but here are a few possible reasons why this Promise MAY be broken:

See also 3.0.7.

  * The application server has already transmitted `Content-Length`, but the application continued to send bytes after that point.

  * The client hungup the connection before it finished sending the response.

### 3.0.2 Raw Socket

The `p6sgix.io` environment variable, if provided, MUST be the bare metal [IO::Socket::INET](IO::Socket::INET) used to communicate to the client. This is the interface of last resort as it sidesteps the entire P6SGI interface. 

If your application requires the use of this socket, please file an issue describing the nature of your application in detail. You may have a use-case that requires revisions to the P6SGI standard to cope with.

### 3.0.3 Logger

The `p6gix.logger` environment variable, if provided, MUST be a [Routine](http://doc.perl6.org/type/Routine) defined with a signature as follows:

```perl6
    sub (Str:D :$level, Str:D :$message);
```

When called application MUST provide a `$level` that is one of: `debug`, `info`, `warn`, `error`, `fatal`.

### 3.0.4 Sessions

The `p6sgix.session` environment variable, if provided, MUST be an [Associative](http://doc.perl6.org/type/Associative) mapping arbitrary keys and values that may be read and written to by an application. The application SHOULD only use [Str](http://doc.perl6.org/type/Str) keys and values. The implementation of persisting this data is up to the application or middleware implementing the session.

The `p6sgix.session.options` environment variable, if provided, MUST be an [Associative](http://doc.perl6.org/type/Associative) mapping implementation-specific keys and values. This allows the application a channel by which to instruct the session handler how to operate.

### 3.0.5 Harikiri Mode

The `p6sgix.harikiri` environment variable, if provided, MUST be a [Bool](http://doc.perl6.org/type/Bool). If set to `True` it signals to the application that the server supports harikiri mode, which allows the application to ask the server to terminate the current work when the request is complete.

The `p6sgix.harikiri.commit` environment variable MAY be set by the application to signal to the server that the current worker should be killed after the current request has been processed.

### 3.0.6 Cleanup Handlers

The `p6sgix.cleanup` environment variable, if provided, MUST be a [Bool](http://doc.perl6.org/type/Bool). If set to `True` it tells the application that the server supports running cleanup handlers after the request is complete.

The `p6sgix.cleanup.handlers` environment variable MUST be provided if the `p6sgix.cleanup` flag is set. This MUST an [Array](http://doc.perl6.org/type/Array). The application adds cleanup handlers to the list by putting [Callable](http://doc.perl6.org/type/Callable)s into the Array (usually by `push`ing). Each handler will be given a copy of the `%env` as the first argument.

If the server supports harikiri mode, it SHOULD allow the cleanup handlers to invoke harikiri mode if they set `p6sgix.hariki.commit` (see 3.0.5).

### 3.0.7 Output Block Detection

The `p6sgix.body.backpressure` environment variable, if provided, MUST be a [Bool](http://doc.perl6.org/type/Bool) flag. It is set to `True` to indicate that the P6SGI server provide response backpressure detection by polling for non-blocking I/O problems. In this case, the server MUST provide the other two environment variables. If `False` or not defined, the server does not provide these two environment variables.

The `p6sgix.body.backpressure.supply` environment variable MUST be provided if `p6sgix.body.backpressure` is `True`. When provided, it MUST be a live [Supply](http://doc.perl6.org/type/Supply) that emits `True` and `False` values. `True` is emitted whenever the server detects a blocked output socket. `False` is emitted whenever the server detects the previously blocked socket is no longer blocked.

The `p6sgix.body.backpressure.test` environment variable MUST be provided if `p6sgix.body.backpressure` is `True`. When provided, it MUST be a [Bool](http://doc.perl6.org/type/Bool) that is `True` while output is blocked and `False` otherwise. This can be useful for detecting the initial state before the backpressure supply has emitted any value or just as a way to poll the last known status of the socket.

Changes
=======

0.5.Draft
---------

  * Adding `p6sgi.ready` and added the Application Lifecycle section to describe the ideal lifecycle of an application.

  * Changed `p6sgi.input` and `p6sgi.errors` to Supply objects.

  * Porting extensions from PSGI and moving the existing extensions into the extension section.

  * Adding some notes about middleware encoding.

  * Renamed `p6sgi.encoding` to `p6sgi.body.encoding`.

  * Renamed `p6sgix.response.sent` to `p6sgix.body.done`.

  * Added `p6sgix.header.done` as a new P6SGI extension.

0.4.Draft
---------

  * Cutting back on some more verbose or unnecessary statements in the standard, trying to stick with just what is important and nothing more.

  * The application response has been completely restructured in a form that is both easy on applications and easy on middleware, mainly taking advantage of the fact that a List easily coerces into a Supply.

  * Eliminating the P6SGI compilation unit again as it is no longer necessary.

  * Change the Supply to emit Cool and Blob rather than just Str and Blob.

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

This second revision eliminates the legacy standard and requires that all P6SGI responses be returned as a [Promise](http://doc.perl6.org/type/Promise). The goal is to try and gain some uniformity in the responses the server must deal with.

0.1.Draft
---------

This is the first published version. It was heavily influenced by PSGI and included interfaces based on the standard, deferred, and streaming responses of PSGI. Instead of callbacks, however, it used [Promise](http://doc.perl6.org/type/Promise) to handle deferred responses and [Channel](http://doc.perl6.org/type/Channel) to handle streaming. It mentioned middleware in passing.
