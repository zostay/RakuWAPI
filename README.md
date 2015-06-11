NAME
====

P6SGI - Perl 6 Web Server Gateway Interface Specification

STATUS
======

This is a Proposed Draft. Given Version 0.1.Draft so that it has some kind of initial designation.

# INTRODUCTION
==============

This document standardizes the interface to be implemented by web application developers in Perl 6. It provides a standard protocol by which application servers may communicate with web applications.

This standard has the following goals:

  * Standardize the interface between server and application so that web developers may focus on application development rather than the nuances of supporting each of several server platforms.

  * Keep the interface simple so that a web application requires no additional tools or libraries other than what exists in a standard Perl 6 environment.

  * Keep the interface simple so that servers are simple to implement.

  * Allow the interface to flexible enough to accomodate a variety of common use-cases and simple optimzations.

  * Provide flexibility so that unanticipated use-cases may be implemented and so that the interface may be extended by servers wishing to do so.

This document is strongly related to the PSGI pecification for Perl 5. Within a Perl 6 environment, it is perfectly acceptable to refer to this standard as "PSGI" with the "6" in "P6SGI" being implied. However, for clarity, P6SGI and PSGI from Perl 5 are quite different because Perl 6 provides a number of built-in tools that greatly simplify several aspects of this specification.

# TERMINOLOGY
=============

A P6SGI application is a Perl 6 subroutine that expects to receive an environment form a *application server* and returns a response each time it is called to be processed by that server.

A Web Server is an application that processes requests and responses according to the HTTP protocol.

An application server is a program that is able to provide an environment to a *P6SGI application* and process the value returned from such such an application.

The *application server* might be associated with a *web server*, might itself be a *web server*, might process a protocol used to communicat with a *web server* (such as CGI or FastCGI), or may be something else entirely not related to a *web server* (such as a tool for testing *P6SGI applications*). 

Middleware is a *P6SGI application* that wraps another *P6SGI application* for the purpose of performing some auxiliary task such as preprocessing request environments, logging, postprocessing responses, etc.

A framework developer is a developer who writes an *application server*.

An application developer is a developer who writes a *P6SGI application*.

# SPECIFICATION
===============

# Application
-------------

A P6SGI application is a Perl 6 [Routine](Routine) that is implemented similar to the following stub

    subset P6SGIResponse of Mu where {
        when Positional { 
               .elems == 3
            && .[0] ~~ Int && .[0] >= 100
            && .[1] ~~ Positional && [&&] .[1].flatmap(* ~~ Pair)
            && .[2] ~~ Iterable|Channel
        }
        when Promise { True }
        default { die "invalid response" }
    };
    method app(%env) returns P6SGIResponse { ... }

However, the `P6SGIResponse` subset is not actually defined anywhere, but is useful for showing many of the requirements placed on the return value. 

That is, a trivial P6SGI application could be implemented like this:

    sub app(%env) {
        return (
            200,
            [ Content-Type => 'text/plain' ],
            [ "Hello World" ],
        );
    }

# Environment
-------------

The environment MUST be an [Associative](Associative) that includes a number of values adopted from the old Common Gateway Interface as well as a number of additional P6SGI-specific values. The application server MUST provide each key as the type given. 

### # CGI and PSGI Environment

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
    <td>C&lt;REQUEST_METHOD&gt;</td>
    <td>C&lt;&lt; Str:D where *.chars &gt; 0 &gt;&gt;</td>
    <td>The HTTP request method, such as "GET" or "POST".</td>
  </tr>
  <tr>
    <td>C&lt;SCRIPT_NAME&gt;</td>
    <td>C&lt;&lt; Str:D where any('', m{ ^ "/" }) &gt;&gt;</td>
    <td>This is the initial prtion of the URL path that refers to the application.</td>
  </tr>
  <tr>
    <td>C&lt;PATH_INFO&gt;</td>
    <td>C&lt;&lt; Str:D where any('', m{ ^ "/" }) &gt;&gt;</td>
    <td>This is the remainder of the request URL path within the application. This value SHOULD be URI decoded by the application server according to L&lt;RFC 3875|http://www.ietf.org/rfc/rfc3875&gt;</td>
  </tr>
  <tr>
    <td>C&lt;REQUEST_URI&gt;</td>
    <td>C&lt;&lt; Str:D &gt;&gt;</td>
    <td>This is the exact URL sent by the client in the request line of the HTTP request. The application server SHOULD NOT perform any decoding on it.</td>
  </tr>
  <tr>
    <td>C&lt;QUERY_STRING&gt;</td>
    <td>C&lt;&lt; Str:D &gt;&gt;</td>
    <td>This is the portion of the requested URL following the C&lt;?&gt;, if any.</td>
  </tr>
  <tr>
    <td>C&lt;SERVER_NAME&gt;</td>
    <td>C&lt;&lt; Str:D where *.chars &gt; 0 &gt;&gt;</td>
    <td>This is the server name of the web server.</td>
  </tr>
  <tr>
    <td>C&lt;SERVER_PORT&gt;</td>
    <td>C&lt;&lt; Int:D where * &gt; 0 &gt;&gt;</td>
    <td>This is the server port of the web server.</td>
  </tr>
  <tr>
    <td>C&lt;SERVER_PROTOCOL&gt;</td>
    <td>C&lt;&lt; Str:D where *.chars &gt; 0 &gt;&gt;</td>
    <td>This is the server protocol sent by the client. Typically set to "HTTP/1.1" or a similar value.</td>
  </tr>
  <tr>
    <td>C&lt;CONTENT_LENGTH&gt;</td>
    <td>C&lt;&lt; Int:_ &gt;&gt;</td>
    <td>This corresponds to the Content-Length header sent by the client. If no such header was sent the application server SHOULD set this key to the L&lt;Int&gt; type value.</td>
  </tr>
  <tr>
    <td>C&lt;CONTENT_TYPE&gt;</td>
    <td>C&lt;&lt; Str:_ &gt;&gt;</td>
    <td>This corresponds to the Content-Type header sent by the cilent. If no such header was sent the application server SHOULD set this key to the L&lt;Str&gt; type value.</td>
  </tr>
  <tr>
    <td>C&lt;HTTP_*&gt;</td>
    <td>C&lt;&lt; Str:_ &gt;&gt;</td>
    <td>The remaining request headers are placed here. The names are prefixed with C&lt;HTTP_&gt;, in ALL CAPS with the hyphens ("-") turned to underscores ("_"). Multiple incoming headers with the same name should be joined with a comma (", ") as described in L&lt;RFC 2616|http://www.ietf.org/rfc/rfc2616&gt;. The C&lt;HTTP_CONTENT_LENGTH&gt; and C&lt;HTTP_CONTENT_TYPE&gt; headers MUST NOT be set.</td>
  </tr>
  <tr>
    <td>Other CGI Keys</td>
    <td>C&lt;&lt; Str:_ &gt;&gt;</td>
    <td>The server SHOULD attempt to provide as many other CGI variables as possible, but no others are required or formally specified.</td>
  </tr>
  <tr>
    <td>C&lt;psgi.version&gt;</td>
    <td>C&lt;&lt; Version:D &gt;&gt;</td>
    <td>This is the version of this specification, C&lt;v0.1.DRAFT&gt;.</td>
  </tr>
  <tr>
    <td>C&lt;psgi.url-scheme&gt;</td>
    <td>C&lt;&lt; Str:D &gt;&gt;</td>
    <td>Either "http" or "https".</td>
  </tr>
  <tr>
    <td>C&lt;psgi.input&gt;</td>
    <td>Like C&lt;&lt; IO::Handle:_ &gt;&gt;</td>
    <td>The input stream for reading the body of the request, if any.</td>
  </tr>
  <tr>
    <td>C&lt;psgi.input.buffered&gt;</td>
    <td>C&lt;&lt; Bool:D &gt;&gt;</td>
    <td>True if the input stream is buffered and seekable.</td>
  </tr>
  <tr>
    <td>C&lt;psgi.errors&gt;</td>
    <td>Like C&lt;&lt; IO::Handle:D &gt;&gt;</td>
    <td>The error stream for logging.</td>
  </tr>
  <tr>
    <td>C&lt;psgi.errors.buffered&gt;</td>
    <td>C&lt;&lt; Bool:D &gt;&gt;</td>
    <td>True if the error stream is buffered.</td>
  </tr>
  <tr>
    <td>C&lt;psgi.multithread&gt;</td>
    <td>C&lt;&lt; Bool:D &gt;&gt;</td>
    <td>True if the app may be simultaneously invoked in another thread in the same process.</td>
  </tr>
  <tr>
    <td>C&lt;psgi.multiprocess&gt;</td>
    <td>C&lt;&lt; Bool:D &gt;&gt;</td>
    <td>True if the app may be simultaneously invoked in another process.</td>
  </tr>
  <tr>
    <td>C&lt;psgi.run-once&gt;</td>
    <td>C&lt;&lt; Bool:D &gt;&gt;</td>
    <td>True if the server expects the app to be invoked only once during the life of the process. This is not a guarantee.</td>
  </tr>
  <tr>
    <td>C&lt;psgi.streaming&gt;</td>
    <td>C&lt;&lt; Bool:D &gt;&gt;</td>
    <td>True if the server supports deplayed response and streaming interfaces.</td>
  </tr>
  <tr>
    <td>C&lt;psgi.encoding&gt;</td>
    <td>C&lt;&lt; Str:D &gt;&gt;</td>
    <td>Name of the encoding the server will use for any strings it is sent.</td>
  </tr>
</table>

In the environment, either `SCRIPT_NAME` or `PATH_INFO` must be set to a non-empty string. When `REQUEST_URI` is "/", the `PATH_INFO` SHOULD be "/" and `SCRIPT_NAME` SHOULD be the empty string. `SCRIPT_NAME` MUST NOT be set to "/".

For those familiar with Perl 5 PSGI, you may want to take care when working with some of these values. A few look very similar, but are subtly different. For example, the setting called "psgix.input.buffered" in that standard is called "psgi.input.buffered" here.

The server or the application may store its own data in the environment as well. These keys MUST contain at least one dot, SHOULD be prefixed uniquely.

The following prefixes are reserved for use by this standard:

  * `psgi.` is for P6SGI core standard environment values.

  * `psgix.` is for P6SGI standard extensions environment values.

### # The Input Stream

The input stream is set in the `psgi.input` key of the environment. It is provided as an object that provides some of the methods of [IO::Handle](IO::Handle). Most servers will probably just use an [IO::Handle](IO::Handle) object, but this is not required. 

The input stream object provided by the server is defined with the following methods:

  * read

        method read(Int:D $bytes) returns Blob { ... }

    This method MUST be available. This method is given the number of bytes to read from the input stream and returns a [Blob](Blob) containing up to that many bytes or a Blob type object if the stream has come to an end.

  * seek

        method seek(Int:D $offset, Int:D $whence where 0 >= * >= 2) returns Bool { ... }

    This method MAY be provided in all cases, but MUST be provided if `psgi.input.buffered` is set in the environment. Calling this moves the read cursor to byte position `$offset` relative to `$whence`, which is one of the following integers:

      * `0`: Seek from the start of the file.

      * `1`: Seek from the current read cursor position.

      * `2`: Seek from the end of the file.

    This method returns True on successful seek.

The application SHOULD NOT check to see if the input stream is an [IO::Handle](IO::Handle), but just make use of the methods provided.

### # The Error Stream

The error stream in `psgi.errors` is also an [IO::Handle](IO::Handle)-like object, used to log application errors. The server SHOULD write these errors to an appropriate log, console, etc. 

The error stream implements the following methods:

  * print

        multi method print(Str:D: $error) returns Bool:D { ... }
        multi method print(*@error) returns Bool:D { ... }

    Both multi variants MUST be provided. The slurpy version using `@error` will concatenate the stringified version of each value given for recording.

    Both variants return True on success.

  * flush

        method flush() returns Bool:D { ... }

    This method MUST be provided. It MAY be a no-op, particularly if `psgi.errors.buffered` is False. It SHOULD flush the error stream buffer. It returns True on success.

The application SHOULD NOT check to see if the errors stream is an [IO::Handle](IO::Handle), but just make use of the methods provided.

# The Response
--------------

The return value from a P6SGI applicaiton MUST be a three element [Positional](Positional) or a [Channel](Channel).

### # Positional Response

This interface MUST be implemented by application servers. When the application provides a [Positional](Positional) response, it MUST have exactly 3 elements. Because of this, a [Parcel](Parcel) is a common [Positional](Positional) implementation to use. However, the server MUST NOT check what type of [Positional](Positional) it is and depend upon the usual `postcircumfix:<[ ]> ` operator to find the 3 required elements.

The elements are as follows:

#### # Status 

The first element is the HTTP status code. It MUST be an [Int](Int) greater than or equal to 100. It SHOULD be an HTTP status code documented in [RFC 2616](RFC 2616).

#### # Headers

The headers MUST be provided as a [Positional](Positional) of [Pair](Pair). It MUST NOT be provided as an [Associative](Associative). 

All keys MUST consist only of letters, digits, underscores ("_"), and hyphens ("-"). All keys MUST start with a letter. The headers SHOULD contain only ASCII compatible characters.

The values MUST be strings and MUST NOT contain any characters below octal 037, i.e., `chr(31)`. The headers SHOULD contain only ASCII-compatible characters.

If the same key name appears multiple times in the [Positional](Positional), those header lines MUST be sent to the client separately by the server.

The following headers require special consideration:

  * `Content-Type`. There MUST NOT be a `Content-Type` header when the [#Status](#Status) is 1xx, 204, 205, or 304.

  * `Content-Length`. There MUST NOT be a `Content-Length` header when the [#Status](#Status) is 1xx, 204, 205, or 304.

In any other case, the application server MAY calculate the content length by examining the body and send the `Content-Length`. It SHOULD NOT do this, though, when working with a streaming response body (as this would defeat the purpose of streaming).

#### # Body

The response body MUST take one of two forms. Either it is provided as an [Iterable](Iterable) object or as a [Channel](Channel).

##### # Iterable Body

Application servers MUST implement this interface. An [Iterable](Iterable) body is the simplest and most common case. The elements contained within the Iterable SHOULD be [Blob](Blob)s. The elements returned by the iterable object MAY be [Str](Str)s. See [#Encoding](#Encoding) for details on how each [Str](Str) is to be handled.

The application server SHOULD write each [Blob](Blob) found in the returned body as-is to the client. It SHOULD NOT care what the contents are.

Here are some example bodies:

    my $body = [ "Hello World".encode ];
    my $body = map *.encode, "Hello\n", "World\n";
    my $body = [ "/path/to/file".IO.slurp(:bin) ];

    my $h = open "/path/to/file", :r;
    my $body = $h.lines;

    my $h = open "/path/to/file", :r;
    my $body = gather loop { take $h.read(4096) or last };

##### # Channel Body

This interface SHOULD be implemented by application servers. This interface MUST be implemented if `psgi.streaming` is True in the environment.

The P6SGI application uses the given [Channel](Channel) to send a series of [Blob](Blob) or [Str](Str) objects to the server. The application SHOULD use Blobs whenever possible, but may use Strs. The application server receives these Blob objects and SHOULD write each one to the client as-is. See [#Encoding](#Encoding) for details on how each [Str](Str) is to be handled.

For example, here is an application that feeds events tapped from a [Supply](Supply) to the server via a returned [Channel](Channel).

    my &app = sub (%env) {
        my $events = Supply.new;
        $*SCHEDULER.cue: { 
            loop { 
                given event-reader() {
                    when Event { $events.emit(.to-json) }
                    when Fin   { $events.done }
                }
            }
        };

        return ( 
            200, 
            [ Content-Type => 'application/json' ], 
            $events.Channel
        );
    };

The application server closes the response when the [Channel](Channel) is closed.

##### # Encoding

It is permissable for applications to return elements of the body using [Str](Str)s. However, if strings are used rather than [Blob](Blob) buffers, you are placing the server in charge of encoding your data. The server MUST provide a `psgi.encoding` in the environment. This names the encoding the server will use to encode strings encountered in the body. 

In addition to this, the server SHOULD attempt to read the `charset` value in the `Content-Type` header to select an encoding. It will fallback to `psgi.encoding` if no `charset` is detected or it is unable to understand it.

Application developers are adviced to encode their own data, however. A P6SGI application SHOULD use [Blob](Blob)s instead of [Str](Str)s.

### # Promise Response

This interface SHOULD be implemented by application servers. This interface MUST be implemented if `psgi.streaming` is True in the environment.

The P6SGI application may return a [Promise](Promise). This [Promise](Promise) will be kept with a [Positional](Positional) as described in [#Positional_Response](#Positional_Response), either with a [Iterable](Iterable) body or with a [Channel](Channel) body.

This allows the P6SGI application to delay the reponse to be returned at a later time. For example,

    my &app = sub (%env) {
        start { 
            my $result = long-running-process();
            if $result.success {
                (
                    200,
                    [ Content-Type => 'application/json' ],
                    $result.json-stremaing-channel
                )
            }
            else {
                (
                    500,
                    [ Content-Type => 'text/plain' ],
                    [ 'Bad Stuff'.encode ],
                )
            }
        }
    }

The `start` call will return a [Promise](Promise) that is kept as required.

The applicaiton server MUST await the keeping of the Promise for some period of time and send the client the response as required in the sections above.

# Middleware
------------

A middleware component is a P6SGI application that wraps another P6SGI application. As such it acts both as application server and application. In the process, it may preprocess the environment, postprocess the response, perform logging, validation, security enhancements, debugging tools, or just about anything else someone might imagine adding onto an application.

For example, here is one that adds a custom header:

    my &app = sub (%env) {
        (
            200,
            [ Content-Type => 'text/plain' ],
            [ 'Hello World'.encode ],
        );
    }

    my &mw = sub (%env) {
        my @res = app(%env);
        @res[1].push: (X-PSGI-Used => 'True');
        @res;
    };

Middleware MUST adhere to the requirements of a P6SGI application. Middleware MAY support streaming bodies, but SHOULD leave any parts of the original application output it does not understand alone, passing it through to the calling application server (which may itself be another middleware component).
