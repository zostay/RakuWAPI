NAME
====

P6SGI - Perl 6 Web Server Gateway Interface Specification

STATUS
======

This is a Proposed Draft.

Version 0.7.Draft

0 INTRODUCTION
==============

This document standardizes an API for web application and server framework developers in Perl 6. It provides a standard protocol by which web applications and application servers may communicate with each other.

This standard has the following goals:

  * Standardize the interface between server and application so that web developers may focus on application development rather than the nuances of supporting different server platforms.

  * Keep the interface simple so that a web application or middleware requires no additional tools or libraries other than what exists in a standard Perl 6 environment, and no module installations are required.

  * Keep the interface simple so that servers and middleware are simple to implement.

  * Allow the interface to be flexible enough to accommodate a variety of common use-cases and simple optimzations.

  * Provide flexibility so that unanticipated use-cases may be implemented and so that the interface may be extended by servers wishing to do so.

Aside from that is the underlying assumption that this is a simple interface and ought to at least somewhat resemble work in the standards it is derived from, including [Rack](http://www.rubydoc.info/github/rack/rack/master/file/SPEC), [WSGI](https://www.python.org/dev/peps/pep-0333/), [PSGI](https://metacpan.com/pod/PSGI), [CGI](http://www.w3.org/CGI/), and others.

1 TERMINOLOGY
=============

A P6SGI application is a Perl 6 routine that expects to receive an environment from an *application server* and returns a response each time it is called by the server.

A Web Server is an application that processes requests and responses according to a web-related protocol, such as HTTP or WebSockets or similar protocol.

The origin is the external entity that makes a given request and/or expects a response from the application server. This can be thought of generically as a web browser, bot, or other user agent.

An application server is a program that is able to provide an environment to a *P6SGI application* and process the value returned from such an application.

The *application server* might be associated with a *web server*, might itself be a *web server*, might process a protocol used to communicate with a *web server* (such as CGI or FastCGI), or may be something else entirely not related to a *web server* (such as a tool for testing *P6SGI applications*).

Middleware is a *P6SGI application* that wraps another *P6SGI application* for the purpose of performing some auxiliary task such as preprocessing request environments, logging, postprocessing responses, etc.

A framework developer is a developer who writes an *application server*.

An application developer is a developer who writes a *P6SGI application*.

A sane Supply is a Supply object that follows the emit*-done/quit protocol, i.e., it will emit 0 or more objects followed by a call to the done or quit handler. See [Supply](http://doc.perl6.org/type/Supply) for details.

2 SPECIFICATION
===============

This specification is divided into three layers:

  * Layer 0: Server

  * Layer 1: Middleware

  * Layer 2: Application

Each layer has a specific role related to the other layers. The server layer is responsible for managing the application lifecycle and performing communication with the origin. The application layer is responsible for receiving metadata and content from the server and delivering metadata and content back to the server. The middleware layer is responsible for enhancing the application or server by providing additional services and utilities.

This specification goes through each layer in order. In the process, each section only specifies the requirements and recommendations for the layer that section describes. When other layers a mentioned outside of its section, the specification is deliberately vague to keep all specifics in the appropriate section. 

To aid in reading this specification, the numbering subsections of 2.0, 2.1, and 2.2 are matched so that you can navigate between them to compare the requirements of each layer. For example, 2.0.1 describes the environment the server provides, 2.1.1 describes how the application interacts with that environment, and 2.2.1 describes how middleware may manipulate that environment.

2.0 Layer 0: Server
-------------------

A P6SGI application server is a program capable of running P6SGI applications as defined by this specification.

A P6SGI application server implements some kind of web service. For example, this may mean implementing an HTTP or WebSocket service or a related protocol such as CGI, FastCGI, SCGI, etc. An application server also manages the application lifecycle and executes the application, providing it with a complete environment, and processing the response from the application to determine how to respond to the origin.

An application server SHOULD strive to be as flexible as possible to allow as many unusual interactions, subprotocols, and upgrade protocols to be implemented as possible within the connection.

One important aspect of this specification that is not defined is the meaning of a server error. At times it is suggested that certain states be treated as a server error, but what that actually means to a given implementation is deliberatly undefined. That is a complex topic which varies by implementation and by the state the server is in when such a state is discovered. The server SHOULD log such events and SHOULD use the appropriate means of communication provided to notify the application that a server error has occurred while responding.

### 2.0.0 Locating Applications

The server MUST be able to find applications.

It SHOULD be able to load applications found in P6SGI script files. These are Perl 6 code files that end with the definition of a routine with arity 1 to be used as the application routine. For example:

```perl6
    use v6;
    sub app(%env) {
        start {
            200, [ Content-Type => 'text/plain' ], [ 'Hello World!' ]
        }
    }
```

These files MAY have a .p6w suffix.

### 2.0.1 The Environment

The environment MUST be an [Associative](http://doc.perl6.org/type/Associative). The keys of this map are mostly derived from the old Common Gateway Interface (CGI) as well as a number of additional P6SGI-specific values. The application server MUST provide each key as the named type. All variables given in the table below MUST be supported, except for those with the `p6wx.` prefix.

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
    <td><code>Str:D where *.chars &gt; 0</code></td>
    <td>The HTTP request method, such as "GET" or "POST".</td>
  </tr>
  <tr>
    <td><code>SCRIPT_NAME</code></td>
    <td><code>Str:D where any('', m{ ^ "/" })</code></td>
    <td>This is the initial portion of the URI path that refers to the application.</td>
  </tr>
  <tr>
    <td><code>PATH_INFO</code></td>
    <td><code>Str:D where any('', m{ ^ "/" })</code></td>
    <td>This is the remainder of the request URI path within the application. This value SHOULD be URI decoded by the application server according to <a href="http://www.ietf.org/rfc/rfc3875">RFC 3875</a></td>
  </tr>
  <tr>
    <td><code>REQUEST_URI</code></td>
    <td><code>Str:D</code></td>
    <td>This is the exact URI sent by the client in the request line of the HTTP request. The application server SHOULD NOT perform any decoding on it.</td>
  </tr>
  <tr>
    <td><code>QUERY_STRING</code></td>
    <td><code>Str:D</code></td>
    <td>This is the portion of the requested URL following the <code>?</code>, if any.</td>
  </tr>
  <tr>
    <td><code>SERVER_NAME</code></td>
    <td><code>Str:D where *.chars &gt; 0</code></td>
    <td>This is the name of the web server.</td>
  </tr>
  <tr>
    <td><code>SERVER_PORT</code></td>
    <td><code>Int:D where * &gt; 0</code></td>
    <td>This is the port number of the web server.</td>
  </tr>
  <tr>
    <td><code>SERVER_PROTOCOL</code></td>
    <td><code>Str:D where *.chars &gt; 0</code></td>
    <td>This is the server protocol sent by the client, e.g. "HTTP/1.0" or "HTTP/1.1".</td>
  </tr>
  <tr>
    <td><code>CONTENT_LENGTH</code></td>
    <td><code>Int:_</code></td>
    <td>This corresponds to the Content-Length header sent by the client. If no such header was sent the application server SHOULD set this key to the L&lt;Int&gt; type value.</td>
  </tr>
  <tr>
    <td><code>CONTENT_TYPE</code></td>
    <td><code>Str:_</code></td>
    <td>This corresponds to the Content-Type header sent by the client. If no such header was sent the application server SHOULD set this key to the L&lt;Str&gt; type value.</td>
  </tr>
  <tr>
    <td><code>HTTP_*</code></td>
    <td><code>Str:_</code></td>
    <td>The remaining request headers are placed here. The names are prefixed with <code>HTTP_</code>, in ALL CAPS with the hyphens ("-") turned to underscores ("_"). Multiple incoming headers with the same name SHOULD have their values joined with a comma (", ") as described in <a href="http://www.ietf.org/rfc/rfc2616">RFC 2616</a>. The <code>HTTP_CONTENT_LENGTH</code> and <code>HTTP_CONTENT_TYPE</code> headers MUST NOT be set.</td>
  </tr>
  <tr>
    <td>Other CGI Keys</td>
    <td><code>Str:_</code></td>
    <td>The server SHOULD attempt to provide as many other CGI variables as possible, but no others are required or formally specified.</td>
  </tr>
  <tr>
    <td><code>p6w.version</code></td>
    <td><code>Version:D</code></td>
    <td>This is the version of this specification, <code>v0.7.Draft</code>.</td>
  </tr>
  <tr>
    <td><code>p6w.url-scheme</code></td>
    <td><code>Str:D</code></td>
    <td>Either "http" or "https".</td>
  </tr>
  <tr>
    <td><code>p6w.input</code></td>
    <td><code>Supply:D</code></td>
    <td>The input stream for reading the body of the request, if any.</td>
  </tr>
  <tr>
    <td><code>p6w.errors</code></td>
    <td><code>Supplier:D</code></td>
    <td>The error stream for logging.</td>
  </tr>
  <tr>
    <td><code>p6w.ready</code></td>
    <td><code>Promise:D</code></td>
    <td>This is a vowed Promise that MUST be kept by the server as soon as the server has tapped the application's output Supply and is ready to receive emitted messages. The value of the kept Promise is irrelevent. The server SHOULD NOT break this Promise.</td>
  </tr>
  <tr>
    <td><code>p6w.multithread</code></td>
    <td><code>Bool:D</code></td>
    <td>True if the app may be simultaneously invoked in another thread in the same process.</td>
  </tr>
  <tr>
    <td><code>p6w.multiprocess</code></td>
    <td><code>Bool:D</code></td>
    <td>True if the app may be simultaneously invoked in another process.</td>
  </tr>
  <tr>
    <td><code>p6w.run-once</code></td>
    <td><code>Bool:D</code></td>
    <td>True if the server expects the app to be invoked only once during the life of the process. This is not a guarantee.</td>
  </tr>
  <tr>
    <td><code>p6w.protocol</code></td>
    <td><code>Set:D</code></td>
    <td>This is a L&lt;Set&gt; containing the names of response protocols the server is able to process from the applicaiton. This specification defines "http" and "ws" protocols.</td>
  </tr>
  <tr>
    <td><code>p6w.body.encoding</code></td>
    <td><code>Str:D</code></td>
    <td>Name of the encoding the server will use for any strings it is sent.</td>
  </tr>
</table>

In the environment, either `SCRIPT_NAME` or `PATH_INFO` must be set to a non-empty string. When `REQUEST_URI` is "/", the `PATH_INFO` SHOULD be "/" and `SCRIPT_NAME` SHOULD be the empty string. `SCRIPT_NAME` MUST NOT be set to "/".

For those familiar with Perl 5 PSGI, you may want to take care when working with some of these values. A few look very similar, but are subtly different.

The server or middleware or the application may store its own data in the environment as well. These keys MUST contain at least one dot, SHOULD be prefixed with a unique name.

The following prefixes are reserved and SHOULD NOT be used unless defined here and then only according to the requirements of this specification:

  * `p6w.` is for P6SGI core standard environment.

  * `p6wx.` is for P6SGI standard extensions to the environment.

### 2.0.2 The Input Stream

The input stream is set in the `p6w.input` key of the environment. This represents the request payload sent from the origin. The server MUST provide a *sane* [Supply](http://doc.perl6.org/type/Supply) that emits [Blob](http://doc.perl6.org/type/Blob) objects containing the content of the request payload, if any.

### 2.0.3 The Error Stream

The error stream MUST be given in the environment via `p6w.errors`. This MUST be a [Supplier](http://doc.perl6.org/type/Supplier) the server provides for emitting errors. The application MAY call `emit` on the Supplier zero or more times, passing any object that may be stringified. The server SHOULD write these log entries to a suitable log file or to `$*ERR` or wherever appropriate. If written to a typical file handle, it should automatically append a newline to each emitted message.

### 2.0.4 Application Response

The application server supplies a [Set](http://doc.perl6.org/type/Set) of strings to the applicaiton in `p6w.protocol` that specifies the way in which the application server expects the application to response. This specification defines the following response protocols: "http" and "ws". Application servers SHOULD support both of these protocols when appropriate for the `SERVER_PROTOCOL`.

The way the server handles these two protocols responses is defined in section 4.0.

#### 2.0.4.1 WebSocket Response

TBD

### 2.0.5 Application Lifecycle

A P6SGI application server processes requests from an origin, passes the processed request information to the application, waits for the application's response, and then returns the response to the origin. In the simplest example this means handling an HTTP roundtrip. It may also mean implementing a related protocol like CGI or FastCGI or SCGI or something else entirely.

In the modern web, an application may want to implement a variety of complex HTTP interactions. These use-cases are not described by the typical HTTP request-response roundtrip. For example, an application may implement a WebSocket API or an interactive Accept-Continue response or stream data to or from the origin. As such, application servers SHOULD make a best effort to be implemented in such a way as to make this variety applications possible.

The application server SHOULD pass control to the application as soon as the headers have been received and the environment can be constructed. The application server MAY continue processing the message body while the application server begins its work. The server SHOULD NOT emit the contents of the request payload via `p6w.input` yet. The server MUST NOT emit to `p6w.input` at this point unless the [Supply](http://doc.perl6.org/type/Supply) is provided on-demand.

Once the application has returned the response headers and the response payload to the server. The server MUST tap the [Supply](http://doc.perl6.org/type/Supply) representing the response payload as soon as possible. Immediately after tapping the Supply, the application server MUST keep the [Promise](http://doc.perl6.org/type/Promise) (with no value) in `p6w.ready`. The application server SHOULD NOT break this Promise. Immediately after keeping the Promise in `p6w.ready`, the server SHOULD start emitting the contents of the request payload, if any, to `p6w.input`.

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
        callsame.then(-> $p {
            my @res = $p.result;
            @res[1].push: P6SGI-Used => 'True';
            @res;
        });
    };

    &app.wrap(&mw);
```

**Note:** For those familiar with PSGI and Plack should take careful notice that Perl 6 `wrap` has the invocant and argument swapped from the way Plack::Middleware operates. As this method is built-in to Perl 6, in P6SGI, the `wrap` method is always called on the *app* not the *middleware*.

### 2.1.0 Middleware Application

The way middleware is applied to an application varies. There are two basic mechanisms that may be used: the `wrap` method and the closure method. There Is More Than One Way To Do It: Other mechanisms are possible, but left as an exercise for the reader.

In either case, the usual way of executing middleware will be to perform whatever preprocessing the middleware requires, then call the wrapped application (which might itself be middleware), and call `then` on the return value to respond when the application's response becomes available and return another promise. A safe idiom for this is:

```perl6
    my &mw = sub (%env) {
        start { preprocess(%env) }.then({
            await app(%env).then(-> $p {
                postprocess(%env, $p.result);
            });
        });
    };
```

#### 2.1.0.0 Wrap Method

This is the method demonstrated in the example above. Perl 6 provides a `wrap` method which may be used to apply another subroutine as an aspect of the subroutine being wrapped. In this case, the original application may be called using `callsame` or `callwith`.

The disadvantage of this mechanism is that the details of wrapped dispatch are somewhat hidden from the caller, so this mechanism might not provide enough control for all middleware applications.

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

Middleware applications SHOULD pass on the complete environment, only modifying the bits required to perform their purpose. Middleware applications MAY add new keys to the environment as a side-effect. These additional keys MUST contain a period and SHOULD use a unique namespace.

### 2.1.2 The Input Stream

An application server is required to provide the input stream as a [Supply](http://doc.perl6.org/type/Supply) emitting [Blob](http://doc.perl6.org/type/Blob)s. Middleware, however, MAY replace the Supply with one that emits anything that might be useful to the application. 

The input stream provided by the middleware MUST be *sane*.

### 2.1.3 The Error Stream

See sections 2.0.3 and 2.2.3.

### 2.1.4 Application Response

As with an application, middleware MUST return a valid P6SGI response to the server.

See section 4 for details on protocl handling.

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

In this example, we load some libraries from our imaginary main application, we define a simple P6SGI app, we apply some middleware (presumably exported from `MyApp::Middleware`), and then end with the reference to our application. This an example of one method by which an application server will load an application. The only requirement for these scripts is that the main P6SGI application subroutine or a reference to it is the last definition in the file.

It is recommended that such files identify themselves with the suffix .p6w whenever a file suffix is useful.

### 2.2.1 The Environment

The one and only argument passed to the application is an [Associative](http://doc.perl6.org/type/Associative) object containing the environment. The environment variables that MUST be set are defined in section 2.0.1. Additional variables may be provided by your application server and middleware.

The application itself MAY store additional values in the environment as it sees fit. This allows the application to communicate with a server or middleware or just to store information useful for the duration of the request. When the application modifies the environment, the variables set MUST contain a period and SHOULD start with a unique name that is not `p6w.` or `p6wx.` as these are reserved.

### 2.2.2 The Input Stream

During a POST, PUT, or other operation, the client may send along a request payload to your application. The application MAY choose to read the payload using the input stream provided in the `p6w.input` key of the environment. This is a *sane* [Supply](http://doc.perl6.org/type/Supply), which may emit any kind of object. The server will provide a Supply that emits zero or more [Blob](http://doc.perl6.org/type/Blob)s, but application middleware may map that information into other objects.

### 2.2.3 The Error Stream

The application server is required to provide a `p6w.errors` variable in the environment with a [Supplier](http://doc.perl6.org/type/Supplier) object. The application MAY emit any errors or messages here using any object that stringifies. The application SHOULD NOT terminate such messages with a newline as the server will do so if necessary. The applicaiton SHOULD NOT call `done` or `quit` on this object.

### 2.2.4 Application Response

The application MUST return a valid P6SGI response to the server. The format required for this response is determined by examining the `p6w.protocol` variable in the environment. This specification defines the response required when this variable is set to "http" or "ws".

See section 4 on how different application protocols are handled.

3 Extensions
============

In addition to the standard specification, there are a number of extensions that servers or middleware MAY choose to implement. They are completely optional and applications and middleware SHOULD check for their presence before depending on them.

3.0 Header Done
---------------

The `p6wx.header.done` environment variable, if provided, MUST be a vowed [Promise](http://doc.perl6.org/type/Promise). This Promise MUST be kept when the server is done sending or processing the response header. The Promise MUST be broken if the server is unable or unwilling to send the application provided headers.

This is not an exhaustive list, but here are a few possible reasons why this Promise MAY be broken:

  * The headers are invalid and the application server will not send them.

  * An internal error occurred in the application server.

  * The client hungup the connection before the headers could be sent.

3.1 Body Done
-------------

The `p6wx.body.done` environment variable, if provided, MUST be a vowed [Promise](http://doc.perl6.org/type/Promise). This Promise MUST be kept when the server is done sending or processing the response body. The Promise MUST be broken if the server is unable or unwilling to send the complete application body.

This is not an exhaustive list, but here are a few possible reasons why this Promise MAY be broken:

  * The application server has already transmitted `Content-Length`, but the application continued to send bytes after that point.

  * The client hungup the connection before it finished sending the response.

  * An application initiated an HTTP/2 push-promise, which the server had begun to fulfill when it received a cancel message from the client.

3.2 Raw Socket
--------------

The `p6wx.io` environment variable, if provided, MUST be the bare metal [IO::Socket::INET](IO::Socket::INET) used to communicate to the client. This is the interface of last resort as it sidesteps the entire P6SGI interface.

If your application requires the use of this socket, please file an issue describing the nature of your application in detail. You may have a use-case that requires revisions to the P6SGI standard to cope with.

3.3 Logger
----------

The `p6wx.logger` environment variable, if provided, MUST be a [Routine](http://doc.perl6.org/type/Routine) defined with a signature as follows:

```perl6
    sub (Str:D $message, Str:D :$level = 'info');
```

When called application MUST provide a `$level` that is one of: `"debug"`, `"info"`, `"warn"`, `"error"`, `"fatal"`.

3.4 Sessions
------------

The `p6wx.session` environment variable, if provided, MUST be an [Associative](http://doc.perl6.org/type/Associative) mapping arbitrary keys and values that may be read and written to by an application. The application SHOULD only use [Str](http://doc.perl6.org/type/Str) keys and values. The implementation of persisting this data is up to the application or middleware implementing the session.

The `p6wx.session.options` environment variable, if provided, MUST be an [Associative](http://doc.perl6.org/type/Associative) mapping implementation-specific keys and values. This allows the application a channel by which to instruct the session handler how to operate.

3.5 Harikiri Mode
-----------------

The `p6wx.harikiri` environment variable, if provided, MUST be a [Bool](http://doc.perl6.org/type/Bool). If set to `True` it signals to the application that the server supports harikiri mode, which allows the application to ask the server to terminate the current work when the request is complete.

The `p6wx.harikiri.commit` environment variable MAY be set by the application to signal to the server that the current worker should be killed after the current request has been processed.

3.6 Cleanup Handlers
--------------------

The `p6wx.cleanup` environment variable, if provided, MUST be a [Bool](http://doc.perl6.org/type/Bool). If set to `True` it tells the application that the server supports running cleanup handlers after the request is complete.

The `p6wx.cleanup.handlers` environment variable MUST be provided if the `p6wx.cleanup` flag is set. This MUST an [Array](http://doc.perl6.org/type/Array). The application adds cleanup handlers to the array by putting [Callable](http://doc.perl6.org/type/Callable)s into the Array (usually by `push`ing). Each handler will be given a copy of the `%env` as the first argument. The server MUST run these handlers, but only after the application has completely finished returning the response and any response payload.

If the server supports harikiri mode, it SHOULD allow the cleanup handlers to invoke harikiri mode if they set `p6wx.hariki.commit` (see 3.5).

3.7 Output Block Detection
--------------------------

The `p6wx.body.backpressure` environment variable, if provided, MUST be a [Bool](http://doc.perl6.org/type/Bool) flag. It is set to `True` to indicate that the P6SGI server provide response backpressure detection by polling for non-blocking I/O problems. In this case, the server MUST provide the other two environment variables. If `False` or not defined, the server does not provide these two environment variables.

The `p6wx.body.backpressure.supply` environment variable MUST be provided if `p6wx.body.backpressure` is `True`. When provided, it MUST be a live [Supply](http://doc.perl6.org/type/Supply) that periodically emits `True` and `False` values. `True` is emitted when the server polls for backpressure and detects a blocked output socket. `False` is emitted when the server polls for backpressure and detects the previously blocked socket is no longer blocked.

The `p6wx.body.backpressure.test` environment variable MUST be provided if `p6wx.body.backpressure` is `True`. When provided, it MUST be a [Bool](http://doc.perl6.org/type/Bool) that is `True` while output has last been detected as blocked and `False` otherwise. This can be useful for detecting the initial state before the backpressure supply has emitted any value or just as a way to poll the last known status of the socket.

3.8 Protocol Upgrade
--------------------

The `p6wx.protocol.upgrade` environment variable MUST be provided if the server implements the protocol upgrade extension. It MUST be set to an [Set](http://doc.perl6.org/type/Set) of protocol names of protocols the server supports.

When the client makes a protocol upgrade request using an `Upgrade` header, the application MAY request that the server upgrade to one of these supported protocols by sending a `P6SGIx-Upgrade` header back to the server with the named protocol. The application MAY send any other headers related to the Upgrade and MAY send a message payload if the upgrade allows it. These SHOULD override any server supplied values or headers.

The server MUST negotiate the new protocol and enable any environment variables required for interacting through that protocol.

Aside from the protocols named here, additional upgrade protocols may be added by other specifications or implementations. However, the common rule all such upgrades follow is that the application MUST complete work on the current protocol (generally HTTP/1.1) in the current method call.

The server MUST make a new call to the application with a new environment to start processing on the new protocol as is appropriate for that protocol. This lets the application reliably process the activity for a single protocol interaction per subroutine call safely whether an upgrade is performed at the application's request or the protocol is otherwise initiated by the server (e.g., an HTTP/2 request may be initiated by a user agent without an upgrade from HTTP/1.1 or a server MAY automatically perform these upgrades in some or all circumstances depending on implementation).

### 3.8.0 HTTP/2 Protocol Upgrade

The workings of HTTP/2 are similar enough to HTTP/1.0 and HTTP/1.1 that use of a protocol upgrade may not be necessary in most or all use-cases. However, servers MAY choose to delegate this to the application using the protocol upgrade extension.

Servers that support this protocol upgrade MUST place the name "h2c" and/or "h2" into the `p6wx.protocol.upgrade` set, for support of HTTP/2 over cleartext connections and HTTP/2 over TLS, respectively.

The application MUST NOT tap the `p6wx.input` stream when performing this upgrade. The application SHOULD NOT return a message payload aside from an empty [Supply](http://doc.perl6.org/type/Supply).

Once upgraded the application server MUST adhere to all the requirements for HTTP/2 as described in section 4.2. The application will be called again once a web request is received on the upgraded connection and is ready for processing.

### 3.8.1 WebSocket Protocol Upgrade

Servers that support the WebSocket protocol upgrade MUST place the name "websocket" into the `p6wx.protocol.upgrade` set.

The application MUST NOT tap the `p6wx.input` stream when performing this upgrade. The application SHOULD NOT return a message payload aside from an empty [Supply](http://doc.perl6.org/type/Supply).

Once upgraded the application server MUST adhere to all the requirements for WebSocket as described in section 2.0.4.1. The application will be called again immediately after the upgrade is complete to allow it to begin sending and receiving frames.

3.9 Transfer Encoding
---------------------

This extension is only for HTTP/1.1 protocol connections. When the server supports this extension, it MUST provide a `p6wx.http11.transfer-encoding` variable listing the transfer encodings the server supports.

When the application returns a header named `P6SGIx-Transfer-Encoding` with the name of one of the supported transfer encodings, the server MUST apply that transfer encoding to the message payload. If the connection is not HTTP/1.1, the server SHOULD ignore this header.

### 3.9.0 Chunked Encoding

When the server supports and the application requests "chunked" encoding. The application server MUST treat each emitted [Str](http://doc.perl6.org/type/Str) or [Blob](http://doc.perl6.org/type/Blob) as a chunk to be encoded according to [RFC7230](https://tools.ietf.org/html/draft-ietf-httpbis-p1-messaging).

### 3.9.1 Other Encodings

All other encodings should be handled as required by the relevant rules for HTTP/1.1.

### 3.10 HTTP/2 Push Promises

When `p6w.protocol` is "http" and the `SERVER_PROTOCOL` is "HTTP/2", servers SHOULD support the HTTP/2 push promises extension. However, applications SHOULD check to make sure that the `p6wx.h2.push-promise` variable is set before using this extension.

This extension is implemented by providing a variable named `p6wx.h2.push-promise`. When provided, this MUST be a [Supplier](http://doc.perl6.org/type/Supplier).

TBD PUSH_PROMISE message structure.

Upon receiving a message to `p6wx.h2.push-promise`, the server SHOULD schedule a followup call to the application to fulfill the push-promise as if the push-promise were an incoming request from the client. (The push-promise could be canceled by the client, so the call to the application might not actually happen.)

4 Protocol Implementation
=========================

The goal of a P6SGI application server is to allow the application to focus on building web applications without having to implement the mundane details of web protocols. In times past, this was simply a matter of implementing HTTP/1.x or some kind of front-end to HTTP/1.x (such as CGI or FastCGI). While HTTP/1.x is still very important to the web today, new protocols have also become important to modern web applications, such as HTTP/2 and WebSocket.

These protocols may have different interfaces. We want to provide a means by which servers and applications may implement these alternate protocols, which each may have different requirements. To facilitate this, P6SGI provides the `p6w.protocol` variable in the environment. The protocol defined here tells the application what the server is providing and how the application is expected to respond.

This specification defines two protocols "http" and "ws", which are used for handling HTTP-style request-response protocols and WebSocket-style generic sockets.

4.0 HTTP Protocol
-----------------

The "http" protocol should be used for any HTTP-style client-server web protocol, this include HTTP/1.x and HTTP/2 connections over plain text and TLS or SSL.

### 4.0.0 Response

Here is an example application that implements the "http" protocol:

```perl6
    sub app(%env) {
        start {
            200,
            [ Content-Type => 'text/plain' ],
            Supply.from-list([ "Hello World" ]),
        };
    }
```

An application MUST return a [Promise](http://doc.perl6.org/type/Promise). This Promise MUST be kept with a [Capture](http://doc.perl6.org/type/Capture) (or something that becomes one on return). It MUST contain 3 positional elements, which are the status code, the list of ehaders, and the message payload.

  * The status code MUST be an [Int](http://doc.perl6.org/type/Int) or object that coerces to an Int. It MUST be a valid HTTP status code.

  * The headers MUST be a [List](http://doc.perl6.org/type/List) of [Pair](http://doc.perl6.org/type/Pair)s or an object that when coerced into a List becomes a List of Pairs. These pairs name the headers to return with the response. Header names MAY be repeated.

  * The message payload MUST be a *sane* [Supply](http://doc.perl6.org/type/Supply) or an object that coerces into a *sane* Supply.

Here is a more interesting example application demonstrating some of the power of this interface:

```perl6
    sub app(%env) {
        start {
            my $n = %env<QUERY_STRING>.Int;
            200,
            [ Content-Type => 'text/plain' ],
            supply {
                my $acc = 1.FatRat;
                for 1..$n -> $v {
                    emit $acc *= $v;
                    emit "\n";
                }
                done;
            },
        };
    }
```

The example application above will print out all the values of factorial from 1 to N where N is given in the query string. The header is returned immediately, but the lines of the body are returned as the values of factorial are calculated. The asynchronous interface is concise and efficient.

And here is an example demonstrating a couple ways in which coercion can be used by an application:

```perl6
    sub app(%env) {
        my enum HttpStatus (OK => 200, NotFound => 404, ServerError => 500);
        start {
            OK, [ Content-Type => 'text/plain' ], [ 'Hello World' ]
        }
    }
```

In this example, the status is returned using an enumeration which coerces to an appropriate integer value. The payload is returned as a list, which is automatically coerced into a Supply.

Applications SHOULD return a Promise as soon as possible. It is recommended that applications wrap all operations within a `start {}` block to make this automatic.

Application servers SHOULD NOT assume that the returned [Promise](http://doc.perl6.org/type/Promise) will be kept. It SHOULD assume that the Promise has been vowed and MUST NOT try to keep or break the Promise from the application.

### 4.0.1 Status Code

### 4.0.2 Response Headers

### 4.0.3 Message Payload

Applications MUST return a *sane* [Supply](http://doc.perl6.org/type/Supply) that emits nothing for requests whose response must be empty.

For any other request, the application MAY emit zero or more messages in the returned payload Supply. The messages MUST be handled as follows:

  * [Blob](http://doc.perl6.org/type/Blob). Any Blob emitted by the application SHOULD be treated as binary data to be passed through to the origin.

  * [List](http://doc.perl6.org/type/List) of [Pair](http://doc.perl6.org/type/Pair)s. Some response payloads may contain trailing headers. Any List of Pairs emitted should be treated as trailing headers.

  * [Associative](http://doc.perl6.org/type/Associative). Any Associative object emitted should be treated as a message to communicate between layers of the application, middleware, and server. These should be ignored and passed on by middleware to the next layer unless consumed by the current middleware. Any message that reaches the application server but is not consumed by the application server MAY result in a warning being reported, but SHOULD otherwise be ignored.

  * [Mu](http://doc.perl6.org/type/Mu). Any other Mu SHOULD be stringified, if possible, and encoded by the application server. If an object given cannot be stringified, the server SHOULD report a warning.

### 4.0.4 Encoding

The application server SHOULD handle encoding of strings or stringified objects emitted to it. When performing encoding, the application server SHOULD honor the `charset` set within the `Content-Type` header, if given. If it does not honor the `charset`, it MUST encode any strings in the response payload according to the encoding named in `p6w.body.encoding`.

### 4.0.5 HTTP/2 Handling

When a server supports HTTP/2 it SHOULD implement the HTTP/2 Push Promise Extension defined in section 3.10. An application server MAY want to consider implementing HTTP/2 protocol upgrades using the extension described in section 3.8.

### 4.3 WebSocket

Any application server implementing WebSocket MUST adhere to all the requirements described above with the following modifications:

  * The `SERVER_PROTOCOL` MUST be set to "WebSocket/13".

  * The server MUST decode frames received from the client and emit them each to `p6wx.input`. The frames MUST NOT be buffered or concatenated.

  * The server MUST encode frames emitted by the application in the message payload as data frames sent to the client. The frames MUST be separated out as emitted by the application without any buffering or concatenation.

Changes
=======

0.7.Draft
---------

  * Some grammar fixes, typo fixes, and general verbiage cleanup and simplification.

  * Renaming `p6sgi.*` to `p6w.*` and `p6sgix.*` to `p6wx.*`.

  * The errors stream is now a `Supplier` rather than a `Supply` because of recent changes to the Supply interface in Perl 6. Made other supply-related syntax changes because of design changes to S17.

  * Eliminating the requirement that things emitted in the response payload be [Cool](http://doc.perl6.org/type/Cool) if they are to be stringified and encoded. Any stringifiable [Mu](http://doc.perl6.org/type/Mu) is permitted.

  * Adding `p6w.protocol` to handle server-to-application notification of the required response protocol.

  * Breaking sections 2.0.4, 2.1.4, and 2.2.4 up to discuss the difference between the HTTP and WebSocket protocol response requirements.

  * Moving 2.0.5, 2.1.5, and 2.2.5 under 2.*.4 because of the protocol changes made in 2.*.4.

  * Changed `p6wx.protocol.upgrade` from an [Array](http://doc.perl6.org/type/Array) to a [Set](http://doc.perl6.org/type/Set) of supported protocol names.

0.6.Draft
---------

  * Added Protocol-specific details and modifications to the standard HTTP/1.x environment.

  * Adding the Protocol Upgrade extension and started details for HTTP/2 and WebSocket upgrade handling.

  * Adding the Transfer Encoding extension because leaving this to the application or unspecified can lead to tricky scenarios.

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

  * Adding the P6SGI compilation unit to provide basic tools that allow middleware and possibly servers to easily process all standard response forms.

  * Section numbering has been added.

  * Added the Changes section.

  * Use `p6sgi.` prefixes in the environment rather than `psgi.`

0.2.Draft
---------

This second revision eliminates the legacy standard and requires that all P6SGI responses be returned as a [Promise](http://doc.perl6.org/type/Promise). The goal is to try and gain some uniformity in the responses the server must deal with.

0.1.Draft
---------

This is the first published version. It was heavily influenced by PSGI and included interfaces based on the standard, deferred, and streaming responses of PSGI. Instead of callbacks, however, it used [Promise](http://doc.perl6.org/type/Promise) to handle deferred responses and [Channel](http://doc.perl6.org/type/Channel) to handle streaming. It mentioned middleware in passing.
