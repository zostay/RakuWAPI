NAME
====

Web API for Perl 6 (P6W)

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

  * Allow the interface to be flexible enough to accommodate a variety of common use-cases and simple optimzations as well as supporting unanticipated use-cases and future extensions.

Aside from that is the underlying assumption that this is a simple interface and ought to at least somewhat resemble work in the standards it is derived from, including [Rack](http://www.rubydoc.info/github/rack/rack/master/file/SPEC), [WSGI](https://www.python.org/dev/peps/pep-0333/), [PSGI](https://metacpan.com/pod/PSGI), [CGI](http://www.w3.org/CGI/), and others.

1 TERMINOLOGY
=============

A P6W application is a Perl 6 routine that expects to receive an environment from an *application server* and returns a response each time it is called by the server.

A Web Server is an application that processes requests and responses according to a web-related protocol, such as HTTP or WebSockets or similar protocol.

The origin is the external entity that makes a given request and/or expects a response from the application server. This can be thought of generically as a web browser, bot, or other user agent.

An application server is a program that is able to provide an environment to a *P6W application* and process the value returned from such an application.

The *application server* might be associated with a *web server*, might itself be a *web server*, might process a protocol used to communicate with a *web server* (such as CGI or FastCGI), or may be something else entirely not related to a *web server* (such as a tool for testing *P6w applications*).

Middleware is a *P6W application* that wraps another *P6W application* for the purpose of performing some auxiliary task such as preprocessing request environments, logging, postprocessing responses, etc.

A framework developer is a developer who writes an *application server*.

An application developer is a developer who writes a *P6W application*.

A sane Supply is a Supply object that follows the emit*-done/quit protocol, i.e., it will emit 0 or more objects followed by a call to the done or quit handler. See [Supply](http://doc.perl6.org/type/Supply) for details.

2 SPECIFICATION
===============

This specification is divided into three layers:

  * Layer 0: Server

  * Layer 1: Middleware

  * Layer 2: Application

Each layer has a specific role related to the other layers. The server layer is responsible for managing the application lifecycle and performing communication with the origin. The application layer is responsible for receiving metadata and content from the server and delivering metadata and content back to the server. The middleware layer is responsible for enhancing the application or server by providing additional services and utilities.

This specification goes through each layer in order. In the process, each section only specifies the requirements and recommendations for the layer that section describes. When other layers a mentioned outside of its section, the specification is deliberately vague to keep all specifics in the appropriate section. 

To aid in reading this specification, the numbering subsections of 2.0, 2.1, and 2.2 are matched so that you can navigate between them to compare the requirements of each layer. For example, 2.0.1 describes the environment the server provides, 2.1.1 describes how the application interacts with that environment, and 2.1.1 describes how middleware may manipulate that environment.

2.0 Layer 0: Server
-------------------

A P6W application server is a program capable of running P6W applications as defined by this specification.

A P6W application server implements some kind of web service. For example, this may mean implementing an HTTP or WebSocket service or a related protocol such as CGI, FastCGI, SCGI, etc. An application server also manages the application lifecycle and executes the application, providing it with a complete environment, and processing the response from the application to determine how to respond to the origin.

One important aspect of this specification that is not defined is the meaning of a server error. At times it is suggested that certain states be treated as a server error, but what that actually means to a given implementation is deliberatly undefined. That is a complex topic which varies by implementation and by the state the server is in when such a state is discovered. The server SHOULD log such events and SHOULD use the appropriate means of communication provided to notify the application that a server error has occurred while responding.

### 2.0.0 Application Definition

A P6W application is defined as a class or object, which must be implemented according to a particular interface. The application server MUST provide a means by which an application is loaded. The application server SHOULD be able to load them by executing a P6W script file.

For example, here is a simple application:

```perl6
    use v6;
    sub app(%env) {
        start {
            200, [ Content-Type => 'text/plain' ], [ 'Hello World!' ]
        }
    }
```

For full details on how an application is defined, see Section 2.2.0. For details on how a server interacts with the application, see Section 2.0.4.

### 2.0.1 The Environment

The environment is delivered to the application via hashes, they MUST be [Associative](http://doc.perl6.org/type/Associative). The application server makes the environment available to the application at runtime. The environment is used to:

  * Communicate server capabilities to the application,

  * Allow the application to communicate with the server, and

  * Allow the application to respond to calls to the application.

Each variable or key in the environment is described as belonging to one of two roles:

  * A configuration environment variable describes global capabilities and configuration information to application.

  * A runtime environment variable describes per-call information related to the particular request.

Calls to the runtime routine MUST be provided with all required environment variables belonging to either of these roles in the passed environment hash. However, calls to the configuration routine (see 2.0.4) MUST include the configuration envrionment and SHOULD NOT include runtime environment in the passed environment hash.

The server MAY provide variables in the environment in either role in addition to the ones defined here, but they MUST contain a period and SHOULD be given a unique prefix to avoid name clashes.

The following prefixes are reserved and SHOULD NOT be used unless defined by this specification and only according to the definition given here.

  * `p6w.` is for P6W core standard environment.

  * `p6wx.` is for P6W standard extensions to the environment.

In the tables below, a type constraint is given for each variable. The application server MUST provide each key as the named type. All variables given in the tables with 2.0.1.0 and 2.0.1.1 MUST be provided.

#### 2.0.1.0 Configuration Environment

The configuration environment MUST be made available to the application during every call made to the application, both to the configuration routine and the runtime routine.

<table>
  <thead>
    <tr>
      <td>Variable</td>
      <td>Constraint</td>
      <td>Description</td>
    </tr>
  </thead>
  <tr>
    <td><code>p6w.version</code></td>
    <td><code>Version:D</code></td>
    <td>This is the version of this specification, <code>v0.7.Draft</code>.</td>
  </tr>
  <tr>
    <td><code>p6w.errors</code></td>
    <td><code>Supplier:D</code></td>
    <td>The error stream for logging.</td>
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
    <td><code>p6w.protocol.support</code></td>
    <td><code>Set:D</code></td>
    <td>This is a <a href="http://doc.perl6.org/type/Set">Set</a> of strings naming the protocols supported by the application server.</td>
  </tr>
  <tr>
    <td><code>p6w.protocol.enabled</code></td>
    <td><code>SetHash:D</code></td>
    <td>This is the set of enabled protocols. The application may modify this set with those found in <code>p6w.protocol.support</code> to enable/disable protocols the server is permitted to use.</td>
  </tr>
</table>

#### 2.0.1.1 Runtime Environment

Many of the call environment variables are derived from the old Common Gateway Interface (CGI). This environment MUST be given when the application is being called, i.e., whenever the runtime routine is called.

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
    <td>This corresponds to the Content-Length header sent by the client. If no such header was sent the application server SHOULD set this key to the <a href="http://doc.perl6.org/type/Int">Int</a> type value.</td>
  </tr>
  <tr>
    <td><code>CONTENT_TYPE</code></td>
    <td><code>Str:_</code></td>
    <td>This corresponds to the Content-Type header sent by the client. If no such header was sent the application server SHOULD set this key to the <a href="http://doc.perl6.org/type/Str">Str</a> type value.</td>
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
    <td><code>p6w.ready</code></td>
    <td><code>Promise:D</code></td>
    <td>This is a vowed Promise that MUST be kept by the server as soon as the server has tapped the application's output Supply and is ready to receive emitted messages. The value of the kept Promise is irrelevent. The server SHOULD NOT break this Promise.</td>
  </tr>
  <tr>
    <td><code>p6w.body.encoding</code></td>
    <td><code>Str:D</code></td>
    <td>Name of the encoding the server will use for any strings it is sent.</td>
  </tr>
  <tr>
    <td><code>p6w.protocol</code></td>
    <td><code>Str:D</code></td>
    <td>This is a string naming the response protocols the server is expecting from the application for call.</td>
  </tr>
</table>

In the environment, either `SCRIPT_NAME` or `PATH_INFO` must be set to a non-empty string. When `REQUEST_URI` is "/", the `PATH_INFO` SHOULD be "/" and `SCRIPT_NAME` SHOULD be the empty string. `SCRIPT_NAME` MUST NOT be set to "/".

### 2.0.2 The Input Stream

The input stream is set in the `p6w.input` key of the runtime environment. This represents the request payload sent from the origin. Unless otherwise indicated as part of the protocol definition, the server MUST provide a *sane* [Supply](http://doc.perl6.org/type/Supply) that emits [Blob](http://doc.perl6.org/type/Blob) objects containing the content of the request payload. It MAY emit nothing and just signal `done` if the request payload is empty.

### 2.0.3 The Error Stream

The error stream MUST be given in the configuration environment via `p6w.errors`. This MUST be a [Supplier](http://doc.perl6.org/type/Supplier) the server provides for emitting errors. The application MAY call `emit` on the Supplier zero or more times, passing any object that may be stringified. The server SHOULD write these log entries to a suitable log file or to `$*ERR` or wherever appropriate. If written to a typical file handle, it should automatically append a newline to each emitted message.

### 2.0.4 Application Lifecycle

After the application has been defined, it will be called each time the application server needs to respond to the origin. What that means will vary depending on which protocol is needed to appropriately respond to the origin.

These requirements, however, are in held in common regardless of protocol, the application server requirements are as follows:

  * The application server MUST check the return value of the application. If the application return value is [Callable](http://doc.perl6.org/type/Callable), the application has returned a configuration routine. Otherwise, the application has returned a runtime routine.

  * If the application returned a configuration routine, as detected in the previous step, the application server MUST call this routine and pass the configuration environment in a hash as the first argument to the routine. The return value of this routine is the runtime routine for the application.

  * Prior to each call to runtime routine, the application server MUST set the `p6w.protocol` variable to the name of the protocol the server will use to communicate with the application.

  * The server MUST pass the merger of the configuration and runtime environments in a hash as the first argument to the runtime routine.

  * The server MUST receive the return value of runtime routine and process it according to the application protocol in use for this call, the one matching the protocol set in step 3.

The server MUST NOT call the application with `p6w.protocol` set to a protocol that has been previously disabled by the application via the `p6w.protocol.enabled` setting.

For details on how each protocol handles the application call, see section 4.

2.1 Layer 1: Middleware
-----------------------

P6W middleware is simply an application that wraps another application. Middleware is used to perform any kind of pre-processing, post-processing, or side-effects that might be added onto an application. Possible uses include logging, encoding, validation, security, debugging, routing, interface adaptation, and header manipulation.

For example, in the following snippet, `mw` is a middleware application that adds a custom header:

```perl6
    sub app(%env) { start { 200, [ Content-Type => 'text/plain' ], [ 'Hello World' ] } }
    sub mw(&wrappee is copy, %config) returns Callable {
        &wrappee = wrappee(%config) if &wrappee.returns ~~ Callable;
        sub (%env) {
            wrappee(%env).then(
                -> $p {
                    my @r = $p.result;
                    @r[1].push: 'P6W-Used' => 'True';
                    @r
                }
            );
        }
    }
    my &mw-app = &mw.assuming(&app);
```

[**Conjecture:** The above code does not work, but should. The problem is that `.assuming()` does not (as of this writing) preserve the return type of the method called. I have suggested a patch to correct this problem. If that patch or one like it turns out to somehow go against the spirit of `.assuming()` or something, this requires a better example.]

### 2.1.0 Middleware Definition

The way in which middleware is defined and applied is left up to the middleware author. The example in the previous section uses a combination of priming and defining a closure. This is, by no means, the only way to define P6W middleware in Perl 6.

What is important in middleware definition is the following:

  * A middleware application MUST be a P6W application, viz., it MUST be a configuration routine or runtime routine as defined in section 2.2.0.

  * Middleware SHOULD check to see if the application being wrapped returns a configuration routine or a runtime routine by testing whether the return value of the routine is [Callable](http://doc.perl6.org/type/Callable).

  * A middleware configuration routine SHOULD run the wrapped configuration application at configuration time with the configuration environment.

  * A middleware runtime routine SHOULD fail if the wrapped configuration application is a configuration routine.

Otherwise, There Is More Than One Way To Do It.

### 2.1.1 The Environment

Middleware applications MAY set or modify the environment (both configuration and runtime environment) as needed. Middleware applications SHOULD maintain the typing required for the server in Sections 2.0.1.0 and 2.0.1.1 above, as modified by extensions and the application protocol in use. 

Whenever setting new variables in the environment, the variables MUST contain a period and SHOULD use a unique prefix to avoid name clashes with servers, other middleware, and applications.

### 2.1.2 The Input Stream

An application server is required to provide the input stream as a [Supply](http://doc.perl6.org/type/Supply) emitting [Blob](http://doc.perl6.org/type/Blob)s. Middleware, however, MAY replace the Supply with one that emits anything that might be useful to the application. 

Such modifications to input necessarily present compatibility problems with other middleware, so both application and middleware developers SHOULD take care to document and apply such middleware carefully.

The input stream provided by the middleware MUST still be *sane*.

### 2.1.3 The Error Stream

See sections 2.0.3 and 2.2.3.

### 2.1.4 Application Lifecycle

Middleware MUST return a valid response to the server according to the value set in `p6w.protocol` by the server (or whatever middleware came before it).

See sections 2.0.4 and 2.2.4. Middleware MUST adhere to all requirements of the application as respects the server (2.2.4) and all requirements of the server as respects the application (2.0.4).

See section 4 for details on protocol handling.

2.2 Layer 2: Application
------------------------

A P6W application is a Perl 6 routine. The application MUST be [Callable](http://doc.perl6.org/type/Callable). An application may be defined as either a runtime routine or a configuration routine. A configuration routine receives a P6W configuration environment and returns a runtime routine. A runtime routine receives a P6W runtime environment and responds to it by returning a response.

As an example, a simple Hello World P6W application defined with a runtime routine could be implemented as follows:

```perl6
    sub app(%env) {
        start {
            200, [ Content-Type => 'text/plain' ], [ 'Hello World' ]
        };
    }
```

Or, a slightly more complex Hello World application could be implemented using a configuration routine instead like so:

```perl6
    sub app-config(%config) returns Callable {
        %config<p6w.protocol.enabled> ∩= set('request-response');
        sub app(%env) {
            start {
                200, [ Content-Type => 'text/plain' ], [ 'Hello World' ]
            };
        }
    }
```

This second application makes sure that only the request-response protocol is enabled before returning an application only capable of responding that way (see Section 4).

### 2.2.0 Defining an Application

An application is defined in one of two mechanisms, as mentioned in the previous section:

  * A runtime routine defines just the part of the application that reacts to incoming calls from the application server. (See Section 2.2.0.0.)

  * A configuration routine defines a special routine that is called prior to handling any incoming calls from the application server to give the application a chance to communicate with the server. (See Section 2.2.0.1.)

During application defintion, the application MAY also instantiate and apply middleware to be used by the application.

### 2.2.0.0 Runtime Routine

To define an application as a runtime routine, the application is defined as a [Callable](http://doc.perl6.org/type/Callable) (typically a [Routine](http://doc.perl6.org/type/Routine)). This application MUST accept a single parameter, a hash, as its argument. The single parameter will be passed the runtime environment by the application server when called. 

The application SHOULD respond to the caller, the application server, according to the `p6w.protocol` string set in the passed environment.

Here, for example, is a P6W application that calculates and prints the Nth Lucas number depending on the value passed in the query string. This assumes a request-response protocol (see Section 4.0).

```perl6
    sub lucas-app(%env) {
        start {
            my $n = %env<QUERY_STRING>.Int;
            my $lucas-number := 2, 1, * + * ... *;
            200, [ Content-Type => 'text/plain' ], [ $lucas-number[$n] ];
        }
    }
```

This application is vulnerable, however, to problems if the server might call the application with a different protocol.

### 2.2.0.1 Configuration Routine

An application SHOULD return a configuration routine, which is defined just like the runtime routine, but it must constrain its return type to something [Callable](http://doc.perl6.org/type/Callable). This application MUST accept a single parameter, a hash, as its argument, just like the runtime routine. This single parameter, though, will be giving as the smaller configuration environment rather than the runtime environment. This routine will also be called prior to any request or other contact from an origin has occurred, which gives the application the opportunity to communicate with the server early.

The application SHOULD modify the configuration environment to suit the needs of the application. The application SHOULD end the routine by returning a runtime routine (see the previous section).

Here is the example from the previous section, but using a configuration routine to guarantee that the only protocol the application can use to contact it is the request-response protocol (see Section 4.0). It ends by returning the `&lucas-app` subroutine defined in the previous section:

```perl6
    sub lucas-config(%config) returns Callable {
        # Only permit the request-response protocol
        %config<p6w.protocol.enabled> ∩= set('request-response');

        &lucas-app;
    }
```

### 2.2.1 The Environment

Calls to the configuration routine of the application (if defined) will receive the configuration environment as defined in Section 2.0.1.0. Calls to the runtime routine of the application will receive the runtime environment as defined in Section 2.0.1.1. Additional variables may be provided by your application server and middleware in either environment hash.

The application itself MAY store additional values in the environment as it sees fit. This allows the application to communicate with a server or middleware. When the application modifies the environment, the variables set MUST contain a period and SHOULD start with a unique name that is not `p6w.` or `p6wx.` as these are reserved.

### 2.2.2 The Input Stream

Some calls to your application may be accompanied by a request payload. For example, a POST or PUT request sent by an origin using HTTP will typically include such a payload. The applicaiton MAY choose to read the payload using the sane [Supply](http://doc.perl6.org/type/Supply) provided in the `p6w.input` variable of the call environment.

The data supplied will depend on the protocol and middleware employed, but is generally given as a stream of [Blob](http://doc.perl6.org/type/Blob)s by the application server.

### 2.2.3 The Error Stream

The application server is required to provide a `p6w.errors` variable in the environment with a [Supplier](http://doc.perl6.org/type/Supplier) object. The application MAY emit any errors or messages here using any object that stringifies. The application SHOULD NOT terminate such messages with a newline as the server will do so if necessary. The application SHOULD NOT call `done` or `quit` on this object.

### 2.2.4 Application Call

To handle requests from the origin, the application server will make calls to the application routine. The application SHOULD return a valid response to the server. The response required will depend on what string is set in `p6w.protocol` within the call environment, so the application SHOULD check that on every call if it may vary.

The application SHOULD attempt to return a value as quickly as possible via the runtime routine. For protocols that require the application to return a [Promise](http://doc.perl6.org/type/Promise), the application SHOULD wrap the entire body of the call in a `start` block to minimize the time the server will be waiting on the application.

See section 4 on how different application protocols are handled.

3 Extensions
============

In addition to the standard specification, there are a number of extensions that servers or middleware MAY choose to implement. They are completely optional and applications and middleware SHOULD check for their presence before using them. Such checks SHOULD be performed as early as possible, prior to returning the application, if possible.

Unless stated otherwise, all environment variables described are set in the runtime environment, which is passed as the single argument with each call to the application.

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

In particular, `p6wx.body.done` MUST be broken if `p6wx.header.done` is broken (assuming both extensions are implemented).

3.2 Raw Socket
--------------

The `p6wx.io` environment variable, if provided, SHOULD be the socket object used to communicate to the client. This is the interface of last resort as it sidesteps the entire P6W interface, but may be useful in cases where an application wishes to control details of the socket itself.

If your application requires the use of this socket, please file an issue describing the nature of your application in detail. You may have a use-case that a future revision to P6W can improve.

This variable MAY be made available as part of the configuration environment.

3.3 Logger
----------

The `p6wx.logger` environment variable, if provided, MUST be a [Routine](http://doc.perl6.org/type/Routine) defined with a signature as follows:

```perl6
    sub (Str:D $message, Str:D :$level = 'info');
```

When called application MUST provide a `$level` that is one of: `"debug"`, `"info"`, `"warn"`, `"error"`, `"fatal"`.

Te `p6wx.logger` environment variable SHOULD be provided in the configuration environment.

3.4 Sessions
------------

This extension implements basic session handling that allows certain data to persist across requests. Session data SHOULD be associated with a particular origin.

The `p6wx.session` environment variable, if provided, MUST be an [Associative](http://doc.perl6.org/type/Associative). This hash maps arbitrary keys and values that may be read and written to by an application. The application SHOULD only use [Str](http://doc.perl6.org/type/Str) keys and values. The details of persisting this data is up to the application server or middleware implementing the session extension.

The `p6wx.session.options` environment variable, if provided, MUST be an [Associative](http://doc.perl6.org/type/Associative)> This hash uses implementation-specific keys and values to communicate between the application and the extension implementation. This allows the application a channel by which to instruct the session handler how to operate.

3.5 Harakiri Mode
-----------------

The `p6wx.harakiri` environment variable, if provided, MUST be a [Bool](http://doc.perl6.org/type/Bool). If set to `True` it signals to the application that the server supports harakiri mode, which allows the application to ask the server to terminate the current work when the request is complete. This variable SHOULD be set in the configuration environment.

The `p6wx.harakiri.commit` environment variable MAY be set by the application to signal to the server that the current worker should be killed after the current request has been processed.

3.6 Cleanup Handlers
--------------------

The `p6wx.cleanup` environment variable, if provided, MUST be a [Bool](http://doc.perl6.org/type/Bool). If set to `True` it tells the application that the server supports running cleanup handlers after the request is complete. This variable SHOULD be set in the configuration environment.

The `p6wx.cleanup.handlers` environment variable MUST be provided if the `p6wx.cleanup` flag is set. This MUST an [Array](http://doc.perl6.org/type/Array). The application adds cleanup handlers to the array by putting [Callable](http://doc.perl6.org/type/Callable)s into the Array (usually by `push`ing). Each handler will be given a copy of the `%env` as the first argument. The server MUST run these handlers, but only after the application has completely finished returning the response and any response payload.

If the server supports the harakiri extension, it SHOULD allow the cleanup handlers to invoke harakiri mode by setting `p6wx.harakiri.commit` (see 3.5).

3.7 Output Block Detection
--------------------------

The `p6wx.body.backpressure` environment variable, if provided, MUST be a [Bool](http://doc.perl6.org/type/Bool) flag. It is set to `True` to indicate that the P6W server provide response backpressure detection by polling for non-blocking I/O problems. In this case, the server MUST provide the other two environment variables. If `False` or not defined, the server does not provide these two environment variables. This variable SHOULD be defined in the configuration environment.

The `p6wx.body.backpressure.supply` environment variable MUST be provided if `p6wx.body.backpressure` is `True`. When provided, it MUST be a live [Supply](http://doc.perl6.org/type/Supply) that periodically emits `True` and `False` values. `True` is emitted when the server polls for backpressure and detects a blocked output socket. `False` is emitted when the server polls for backpressure and detects the previously blocked socket is no longer blocked.

The `p6wx.body.backpressure.test` environment variable MUST be provided if `p6wx.body.backpressure` is `True`. When provided, it MUST be a [Bool](http://doc.perl6.org/type/Bool) that is `True` while output has last been detected as blocked and `False` otherwise. This can be useful for detecting the initial state before the backpressure supply has emitted any value or just as a way to poll the last known status of the socket.

3.8 Protocol Upgrade
--------------------

The `p6wx.net-protocol.upgrade` environment variable MUST be provided in the configuration environment, if the server implements the protocol upgrade extension. It MUST be the [Set](http://doc.perl6.org/type/Set) of names of protocols the server supports for upgrade.

When the client makes a protocol upgrade request using an `Upgrade` header, the application MAY request that the server negotiate the upgrade to one of these supported protocols by sending a `P6Wx-Upgrade` header back to the server with the named protocol. The application MAY send any other headers related to the Upgrade and MAY send a message payload if the upgrade allows it. These SHOULD override any server supplied values or headers.

The server MUST negotiate the new protocol and enable any environment variables required for interacting through that protocol. After the handshake or upgrade negoatiation is complete, the server MUST make a new call to the application with a new environment to process the remainder of the network request with the origin.

### 3.8.0 HTTP/2 Protocol Upgrade

The workings of HTTP/2 are similar enough to HTTP/1.0 and HTTP/1.1 that use of a protocol upgrade may not be necessary in most or all use-cases. However, servers MAY choose to delegate this to the application using the protocol upgrade extension.

Servers that support this protocol upgrade MUST place the name "h2c" and/or "h2" into the `p6wx.net-protocol.upgrade` set, for support of HTTP/2 over cleartext connections and HTTP/2 over TLS, respectively.

The application MUST NOT request an upgrade using the `P6Wx-Upgrade` header for "h2c" unless the `p6w.url-scheme` is "http". Similarly, the application MUST NOT request an upgrade for "h2" unless the `p6w.url-scheme` is "https". The application server SHOULD enforce this requirement for security reasons.

The application MUST NOT tap the `p6w.input` stream when performing this upgrade. The application SHOULD NOT return a message payload aside from an empty [Supply](http://doc.perl6.org/type/Supply).

### 3.8.1 WebSocket Protocol Upgrade

Servers that support the WebSocket protocol upgrade MUST place the name "ws" into the `p6wx.net-protocol.upgrade` set.

The application MUST NOT tap the `p6w.input` stream when performing this upgrade. The application SHOULD NOT return a message payload aside from an empty [Supply](http://doc.perl6.org/type/Supply).

3.9 Transfer Encoding
---------------------

This extension is only for HTTP/1.1 protocol connections. When the server supports this extension, it MUST provide a `p6wx.http11.transfer-encoding` variable containing a `Set` naming the transfer encodings the server supports as strings. This SHOULD be set in the configuration environment.

When the application returns a header named `P6Wx-Transfer-Encoding` with the name of one of the supported transfer encoding strings, the server MUST apply that transfer encoding to the message payload. If the connection is not HTTP/1.1, the server SHOULD ignore this header.

### 3.9.0 Chunked Encoding

When the server supports and the application requests "chunked" encoding. The application server SHOULD treat each emitted [Str](http://doc.perl6.org/type/Str) or [Blob](http://doc.perl6.org/type/Blob) as a chunk to be encoded according to [RFC7230](https://tools.ietf.org/html/draft-ietf-httpbis-p1-messaging). It MUST adhere to requirements of RFC7230 when sending the response payload to the origin.

### 3.9.1 Other Encodings

All other encodings should be handled as required by the relevant rules for HTTP/1.1.

### 3.10 HTTP/2 Push Promises

When the `SERVER_PROTOCOL` is "HTTP/2", servers SHOULD support the HTTP/2 push promises extension. However, applications SHOULD check to make sure that the `p6wx.h2.push-promise` variable is set to a defined value before using this extension.

This extension is implemented by providing a variable named `p6wx.h2.push-promise`. When provided, this MUST be a [Supplier](http://doc.perl6.org/type/Supplier).

When the application wishes to invoke a server push, it MUST emit a message describing the request the server is pushing. The application server will receive this request and make a new, separate call to the application to fulfill that request.

Push-promise messages are sent as an [Array](http://doc.perl6.org/type/Array) of [Pair](http://doc.perl6.org/type/Pair)s. This is a set of headers to send with the PUSH_PROMISE frame, including HTTP/2 pseudo-headers like ":path" and ":authority".

Upon receiving a message to `p6wx.h2.push-promise`, the server SHOULD schedule a followup call to the application to fulfill the push-promise as if the push-promise were an incoming request from the client. (The push-promise could be canceled by the client, so the call to the application might not actually happen.)

4 Application Protocol Implementation
=====================================

One goal of P6W application servers is to allow the application to focus on building web applications without having to implement the mundane details of web protocols. In times past, this was simply a matter of implementing HTTP/1.x or some kind of front-end to HTTP/1.x (such as CGI or FastCGI). While HTTP/1.x is still relevant to the web today, new protocols have also become important to modern web applications, such as HTTP/2 and WebSocket.

These protocols may have different interfaces that do not lend themselves to the request-response pattern specifed by PSGI. Therefore, we provide a means by which servers and applications may implement these alternate protocols, which each may have different requirements. These protocols are called application protocols to differentiate them from network protocols. For example, rather than providing a protocol for HTTP, we provide the "request-response" protocol. The underlying network protocol may be HTTP/1.0, HTTP/1.1, HTTP/2 or it may be something else that operates according to a similar pattern.

The application and application server SHOULD communicate according to the application protocol used for the current application call. Otherwise, they will be unable to communicate. For many applications, just implementing the basic protocol request-response protocol is enough. However, to allow for more complete applications, P6W provides additional tools to help application and application server to communicate through a variety of situations. This is handled primarily via the `p6w.protocol`, `p6w.protocol.support`, and `p6w.protocol.enabled` values in the environment.

The application SHOULD check the value in `p6w.protocol`. The application SHOULD NOT make assumptions about the network protocol based upon the `p6w.protocol` value for the current request. If the application needs to make a decision based upon the network protocol, the application SHOULD check the `SERVER_PROTOCOL`.

The application SHOULD check `p6w.protocol.support` to discover which protocols are supported by the application server. An application that is not able to support all supported protocols SHOULD modify `p6w.protocol.enabled` to only include protocols supported by the application as early as possible.

The application server MUST provide the `p6w.protocol.support` and `p6w.protocol.enabled` values as part of the configuration environment. The application server MUST NOT use any protocol that is not a member of the `p6w.protocol.enabled` set. If a protocol becomes disabled in the middle of a request, the request MUST continue, but subsequent requests MUST NOT use that protocol unless it is later enabled.

This specification defines the following protocols:

  * **request-response** for request-response protocols, including HTTP

  * **framed-socket** for framed-socket protocols, such as WebSocket

  * **psgi** for legacy PSGI applications

  * **socket** for raw, plain socket protocols, which send and receive data with no expectation of special server handling

It is recommended that an application server that implements all of these protocols only enable the request-response protocol within `p6w.protocol.enabled` by default. This allows simple P6W applications to safely operate without having to perform any special configuration.

4.0 Request-Response Protocol
-----------------------------

The "request-response" protocol SHOULD be used for any HTTP-style client-server web protocol, this include HTTP/1.x and HTTP/2 connections over plain text and TLS or SSL.

### 4.0.0 Response

Here is an example application that implements the "request-response" protocol:

```perl6
    sub app(%env) {
        start {
            200,
            [ Content-Type => 'text/plain' ],
            supply {
                emit "Hello World"
            },
        };
    }
```

An application MUST return a [Promise](http://doc.perl6.org/type/Promise). This Promise MUST be kept with a [Capture](http://doc.perl6.org/type/Capture) (or something that becomes one on return) or MAY be broken. The Capture MUST contain 3 positional elements, which are the status code, the list of headers, and the response payload.

  * The status code MUST be an [Int](http://doc.perl6.org/type/Int) or object that coerces to an Int. It MUST be a valid status code for the [SERVER_PROTOCOL](http://doc.perl6.org/type/SERVER_PROTOCOL).

  * The headers MUST be a [List](http://doc.perl6.org/type/List) of [Pair](http://doc.perl6.org/type/Pair)s or an object that when coerced into a List becomes a List of Pairs. These pairs name the headers to return with the response. Header names MAY be repeated.

  * The message payload MUST be a *sane* [Supply](http://doc.perl6.org/type/Supply) or an object that coerces into a *sane* Supply, such as a [List](http://doc.perl6.org/type/List).

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
            },
        };
    }
```

The example application above will print out all the values of factorial from 1 to N where N is given in the query string. The header is returned immediately, but the lines of the body are returned as the values of factorial are calculated. The asynchronous interface is concise and efficient.

And here is an example demonstrating a couple ways in which coercion can be used by an application to improve readability:

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

### 4.0.1 Response Payload

The response payload, in the result of the application's promise, must be a *sane* [Supply](http://doc.perl6.org/type/Supply). This supply MUST emit nothing for requests whose response must be empty.

For any other request, the application MAY emit zero or more messages in the returned payload Supply. The messages SHOULD be handled as follows:

  * [Blob](http://doc.perl6.org/type/Blob). Any Blob emitted by the application SHOULD be treated as binary data to be passed through to the origin as-is.

  * [List](http://doc.perl6.org/type/List) of [Pair](http://doc.perl6.org/type/Pair)s. Some response payloads may contain trailing headers. Any List of Pairs emitted should be treated as trailing headers.

  * [Associative](http://doc.perl6.org/type/Associative). Any Associative object emitted should be treated as a message to communicate between layers of the application, middleware, and server. These should be ignored and passed on by middleware to the next layer unless consumed by the current middleware. Any message that reaches the application server but is not consumed by the application server MAY result in a warning being reported, but SHOULD otherwise be ignored. These objects MUST NOT be transmitted to the origin.

  * [Mu](http://doc.perl6.org/type/Mu). Any other Mu SHOULD be stringified, if possible, and encoded by the application server. If an object given cannot be stringified, the server SHOULD report a warning.

### 4.0.2 Encoding

The application server SHOULD handle encoding of strings or stringified objects emitted to it. When performing encoding, the application server SHOULD honor the `charset` set within the `Content-Type` header, if given. If it does not honor the `charset`, it MUST encode any strings in the response payload according to the encoding named in `p6w.body.encoding`.

### 4.0.3 Request-Response Lifecycle

The server processes requests from an origin, passes the partially processed request information to the application by calling the application, waits for the application's response, and then returns the response to the origin. In the simplest example this means handling an HTTP roundtrip. Yet, it may also mean implementing a related protocol like CGI or FastCGI or SCGI or something else entirely.

In the modern web, an application may want to implement a variety of complex HTTP interactions. These use-cases are not described by the typical HTTP request-response roundtrip with which most web developers are familiar. For example, an interactive Accept-Continue response or a data stream to or from the origin or an upgrade request to switch protocols. As such, application servers SHOULD make a best effort to be implemented in such a way as to make this variety applications possible.

The application server SHOULD pass control to the application as soon as the headers have been received and the environment can be constructed. The application server MAY continue processing the request payload while the application server begins its work. The server SHOULD NOT emit the request payload to `p6w.input` yet.

Once the application has returned the its [Promise](http://doc.perl6.org/type/Promise) to respond, the server SHOULD wait until the promise is kept. Once kept, the server SHOULD tap the response payload as soon as possible. After tapping the Supply, the application server SHOULD keep the [Promise](http://doc.perl6.org/type/Promise) in `p6w.ready` (the application server SHOULD NOT break this Promise). Once that promise has been kept, only then SHOULD the server start emitting the contents of the request payload, if any, to `p6w.input`.

The server SHOULD return the application response headers back to the origin as soon as they are received. After which, the server SHOULD return each chunk emitted by the response body from the application as soon as possible.

This particular order of operations during the application call will ensure that the application has the greatest opportunity to perform well and be able to execute a variety of novel HTTP interactions.

### 4.0.4 HTTP/1.1 Keep Alive

When an application server supports HTTP/1.1 with keep-alive, each request sent on the connection MUST be handled as a separate call to the application.

### 4.0.4 HTTP/2 Handling

When a server supports HTTP/2 it SHOULD implement the HTTP/2 Push Promise Extension defined in section 3.10. An application server MAY want to consider implementing HTTP/2 protocol upgrades using the extension described in section 3.8 or MAY perform such upgrades automatically instead.

The application MUST be called once for each request or push-promise made on an HTTP/2 stream.

4.1 Framed-Socket Protocol
--------------------------

The "framed-socket" protocol is appropriate for WebSocket-style peer-to-peer TCP connections. The following sections assume a WebSocket connection, but might be adaptable for use with other framed message exchanges, such as message queues or chat servers.

### 4.1.0 Response

Any application server implementing WebSocket MUST adhere to all the requirements described above with the following modifications when calling the application for a WebSocket:

  * The `REQUEST_METHOD` MUST be set to the HTTP method used when the WebSocket connection was negotiated, i.e., usually "GET". Similarly, `SCRIPT_NAME`, `PATH_INFO`, `REQUEST_URI`, `QUERY_STRING`, `SERVER_NAME`, `SERVER_PORT`, `CONTENT_TYPE`, and `HTTP_*` variables in the environment MUST be set to the values from the original upgrade request sent from the origin.

  * The `SERVER_PROTOCOL` MUST be set to "WebSocket/13" or a similar string representing the revision of the WebSocket network protocol which in use.

  * The `CONTENT_LENGTH` SHOULD be set to an undefined [Int](http://doc.perl6.org/type/Int).

  * The `p6w.url-scheme` MUST be set to "ws" for plain text WebSocket connections or "wss" for encrypted WebSocket connections.

  * The `p6w.protocol` MUST be set to "framed-socket".

  * The server MUST decode frames received from the client and emit each of them to `p6w.input`. The frames MUST NOT be buffered or concatenated.

  * The server's supplied `p6w.input` [Supply](http://doc.perl6.org/type/Supply) must be *sane*. The server SHOULD signal `done` through the Supply when either the client or server closes the WebSocket connection normally and `quit` on abnormal termination of the connection.

  * The server MUST encode frames emitted by the application in the message payload as data frames sent to the client. The frames MUST be separated out as emitted by the application without any buffering or concatenation.

The application MUST return a [Promise](http://doc.perl6.org/type/Promise) that is kept with just a [Supply](http://doc.perl6.org/type/Supply) (i.e., not a 3-element Capture as is used with the request-response protocol). The application MAY break this Promise. The application will emit frames to send back to the origin using the promised Supply.

### 4.1.1 Response Payload

Applications MUST return a *sane* [Supply](http://doc.perl6.org/type/Supply) that emits an object for every frame it wishes to return to the origin. The application MAY emit zero or more messages to this supply. The application MAY emit `done` to signal that the connection is to be terminated with the client.

The messages MUST be framed and returned to the origin by the application server as follows, based on message type:

  * [Blob](http://doc.perl6.org/type/Blob). Any Blob emitted by the application SHOULD be treated as binary data, framed exactly as is, and returned to the client.

  * [Associative](http://doc.perl6.org/type/Associative). Any Associative object emitted should be treated as a message to communicate between layers of the application, middleware, and server. These should be ignored and passed on by middleware to the next layer unless consumed by the current middleware. Any message that reaches the application server but is not consumed by the application server MAY result in a warning being reported, but SHOULD otherwise be ignored. These objects MUST NOT be transmitted to the origin.

  * [Mu](http://doc.perl6.org/type/Mu). Any other Mu SHOULD be stringified, if possible, and encoded by the application server. If an object given cannot be stringified, the server SHOULD report a warning.

### 4.1.2 Encoding

The application server SHOULD handle encoding of strings or stringified objects emitted to it. The server MUST encode any strings in the message payload according to the encoding named in `p6w.body.encoding`.

4.2 PSGI Protocol
-----------------

To handle legacy applications, this specification defines the "psgi" protocol. If `p6w.protocol.enabled` has both "psgi" and "request-response" enabled, the "request-response" protocol SHOULD be preferred.

### 4.2.0 Response

The application SHOULD return a 3-element [Capture](http://doc.perl6.org/type/Capture) directly. The first element being the numeric status code, the second being an array of pairs naming the headers to return in the response, and finally an array of values representing the response payload.

### 4.2.1 Payload

The payload SHOULD be delivered as an array of strings, never as a supply.

### 4.2.2 Encoding

String encoding is not defined by this document.

4.3 Socket Protocol
-------------------

The "socket" protocol can be provided by an application server wishing to allow the application to basically take over the socket connection with the origin. This allows the application to implement an arbitrary protocol. It does so, however, in a way that is aimed toward providing better portability than using the socket extension.

The socket provided sends and receives data directly to and from the application without any framing, buffering, or modification. 

The "socket" protocol SHOULD only be used when it is enabled in `p6w.protocol.enabled` and no other protocol enabled there can fulfill the current application call.

4.3.0 Response
--------------

Here's an example application that implements the "socket" protocol to create a naïve HTTP server:

```perl6
    sub app(%env) {
        start {
            supply {
                whenever %env<p6w.input> -> $msg {
                    my $req = parse-http-request($msg);

                    if $req.method eq 'GET' {
                        emit "200 OK HTTP/1.0\r\n";
                        emit "\r\n";
                        emit "Custom HTTP Server";
                    }
                }
            };
        }
    }
```

The socket protocol behaves very much like "framed-socket", but with fewer specified details in the environment. Some of the mandatory environment are not mandatory for the socket protocol.

The following parts of the environment SHOULD be provided as undefined values:

  * REQUEST_METHOD

  * SCRIPT_NAME

  * PATH_INFO

  * REQUEST_URI

  * QUERY_STRING

  * SERVER_NAME

  * SERVER_PORT

  * CONTENT_TYPE

  * HTTP_*

  * p6w.url-scheme

  * p6w.ready

  * p6w.body.encoding

  * SERVER_PROTOCOL

The `p6w.protocol` must be set to "socket".

The application server SHOULD provide data sent by the origin to the application through the `p6w.input` supply as it arrives. It MUST still be a *sane* supply.

The application server MAY tunnel the connection through another socket, stream, file handle, or what-not. That is, the application MAY NOT assume the communication is being performed over any particular medium. The application server SHOULD transmit the data to the origin as faithfully as possible, keeping the intent of the application as much as possible.

The application server SHOULD forward on data emitted by the application in the returned payload supply as it arrives. The application server SHOULD send no other data to the origin over that socket once the application is handed control, unless related to how the data is being tunneled or handled by the server. The application server SHOULD close the connection with the origin when the application server sends the "done" message to the supply. Similarly, the application server SHOULD send "done" the `p6w.input` supply when the connection is closed by the client or server.

### 4.3.1 Response Payload

Applications MUST return a *sane* [Supply](http://doc.perl6.org/type/Supply) which emits a string of bytes for every message to be sent. The messages returned on this stream MUST be [Blob](http://doc.perl6.org/type/Blob) objects. 

### 4.3.2 Encoding

The application server SHOULD reject any object other than a [Blob](http://doc.perl6.org/type/Blob) sent as part of the message payload. The application server is not expected to perform any encoding or stringification of messages.

Changes
=======

0.7.Draft
---------

  * Renamed the standard from Perl 6 Standard Gateway Interface (P6SGI) to the Web API for Perl 6 (P6W).

  * Some grammar fixes, typo fixes, and general verbiage cleanup and simplification.

  * Renaming `p6sgi.*` to `p6w.*` and `p6sgix.*` to `p6wx.*`.

  * The errors stream is now a `Supplier` rather than a `Supply` because of recent changes to the Supply interface in Perl 6. Made other supply-related syntax changes because of design changes to S17.

  * Eliminating the requirement that things emitted in the response payload be [Cool](http://doc.perl6.org/type/Cool) if they are to be stringified and encoded. Any stringifiable [Mu](http://doc.perl6.org/type/Mu) is permitted.

  * Adding `p6w.protocol`, `p6w.protocol.support`, and `p6w.protocol.enabled` to handle server-to-application notification of the required response protocol.

  * Breaking sections 2.0.4, 2.1.4, and 2.2.4 up to discuss the difference between the HTTP and WebSocket protocol response requirements.

  * Moving 2.0.5, 2.1.5, and 2.2.5 under 2.*.4 because of the protocol changes made in 2.*.4.

  * Changed `p6wx.protocol.upgrade` from an [Array](http://doc.perl6.org/type/Array) to a [Set](http://doc.perl6.org/type/Set) of supported protocol names.

  * Split the environment and the application into two parts: configuration and runtime.

  * Added Section 4 to describe protocol-specific features of the specification. Section 4.0 is for HTTP, 4.1 is for WebSocket, 4.2 is for PSGI, and 4.3 is for Socket.

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
