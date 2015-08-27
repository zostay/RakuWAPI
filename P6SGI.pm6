unit module P6SGI;

sub handle-container($con) {
    given ($con) {
        when Positional {
            my ($status, $header, $body) = $con.list;
            given ($body) {
                when Supply {
                    return $status, $header, $body;
                }
                when Iterable {
                    return $status, $header, Supply.from-list($body);
                }
                default {
                    die "unknown response body returned from P6SGI application";
                }
        }
        default {
            die "unknown response form returned from P6SGI application";
        }
    }
}

# usage:
#
#   use P6SGI;
#   &app.wrap(&p6sgi-best-form);

sub as-best-form(%env) is export {
    given (my $res = callsame) {
        when Promise {
            await $res.then({ handle-container($res.result) })
        }
        when Positional {
            Promise.start({ $res });
        }
        default {
            die "unknown response wrapper form returned from P6SGI application";
        }
    }
}

# module App {
#
#     role Adapter[&adapter, &test] {
#         method adapt() {
#             self.wrap({ adapter(callsame) });
#         }
#
#         method adapt-maybe() {
#             self.wrap({
#                 my \r = callsame;
#                 adapter(r) if test(r);
#             });
#         }
#     }
#
#     constant DirectPositional := Adapter[
#         -> @result {
#             Promise.start({ @result[0,1], Supply.from-list(@result[2]) })
#         },
#         -> $result { $result ~~ Positional && $result[2] ~~ Positional },
#     ];
#
#     constant Direct := DirectPositional;
#
#     constant DirectChannel := Adapter[
#         -> @result {
#             Promise.start({ @result[0,1], Supply.from-list(@result[2].list) })
#         },
#         -> $result { $result ~~ Positional && $result[2] ~~ Channel },
#     ];
#
#     constant DirectSupply := Adapter[
#         -> @result {
#             Promise.start({ @result });
#         },
#         -> $result { $result ~~ Positional && $result[2] ~~ Supply },
#     ];
#
#     constant PromisedPositional := Adapter[
#         -> $p {
#             Promise.start({
#                 my @r = $p.result;
#                 @r[0,1], Supply.from-list(@r[2])
#             })
#         },
#         -> $p { $p ~~ Promise && $p.result[2] ~~ Positional },
#     ];
#
#     constant PromisedChannel := Adapter[
#         -> $p {
#             Promise.start({
#                 my @r = $p.result;
#                 @r[0,1], Supply.from-list(@r[2].list) })
#             })
#         },
#         -> $p { $p ~~ Promise && $p.result[2] ~~ Channel },
#     ];
#
#     constant PromisedSupply := Adapter[
#         -> $p { $p },
#         -> $p { $p ~~ Promise && $p.result[2] ~~ Supply },
#     ];
#
#     multi sub trait_mod:<does>(&app, WebApp::Adapter $adapter) is export {
#         &app does $adapter
#         &app.adapt;
#     }
#
#     sub apply-conditional-adapters(&app, *@adapters) {
#         for @adapters -> $adapter {
#             &app does $adapter;
#             &app.adapt-maybe;
#         }
#     }
#
#     sub apply-generic-adapter(&app) {
#         return if &app ~~ Adapter;
#         may-do(&app,
#             DirectPositional, DirectChannel, DirectSupply,
#             PromisedPositional, PromisedChannel, PromisedSupply,
#         );
#     }
# }

# role WebAppMay {
#     has WebAppAdapter:D @!adapters;
#
#     method add-adapter(WebAppAdapter:D $adapter) {
#         @!adapters.push: $adapter;
#     }
#
#     method apply-wrapper() {
#         self.wrap({
#             my \result := callsame;
#             for @!adapters -> $adapter {
#                 if $adapter.test.(result) {
#                     return $adapter.adapter.(result);
#                 }
#             }
#         });
#     }
# }
#
# role WebAppWill {
#     has $!adapter;
#
#     method set-adapter(WebAppAdapter:D $adapter) { $!adapter = $adapter }
#
#     method apply-wrapper(Routine:D &r) {
#         &r.wrap({ $!adapter.adapter.(callsame) });
#     }
# }
#
# multi sub trait_mod:<may>(Routine:D &r, WebAppAdapter:U :$respond-as!) is export {
#     die "cannot combine may respond-as with another will respond-as"
#         if &r ~~ WebAppWill;
#
#     unless &r ~~ WebAppMay {
#         &r does WebAppMay;
#         &r.apply-wrapper;
#     }
#
#     &r.add-adapter($respond-as);
# }
#
# proto sub trait_mod:<will>(|) is export { * }
# multi sub trait_mod:<will>(Routine:D &r, WebAppAdapter:U :$respond-as!) is export {
#     die "cannot combine will respond-as with another will respond-as"
#         if &r ~~ WebAppWill;
#     die "cannot combine will respond-as with may respond-as"
#         if &r ~~ WebAppMay;
#
#     &r does WebAppWill;
#     &r.set-adapter($respond-as);
#     &r.apply-wrapper;
# }
#
# multi sub trait_mod:<may-respond-as>(Routine:D $r, :$direct!) is export {
#
# }
#
# multi sub trait_mod:<may-respond-as>(Routine:D $r, :$legacy-deferred!) is export {
# }
#
# multi sub trait_mod:<may-respond-as>(Routine:D $r, :$legacy-stream!) is export {
# }
#
# multi sub trait_mod:<may-respond-as>(Routine:D $r, :$promise!) is export {
# }
#
# multi sub trait_mod:<may-respond-as>(Routine:D $r, :$stream-channel!) is export {
# }
#
# multi sub trait_mod:<may-respond-as>(Routine:D $r, :$stream-supply!) is export {
# }
#
# multi sub trait_mod:<responds-as>(Routine:D $r, :$direct!) is export {
#     $r.wrap(sub (%env) {
#         Promise.start({
#             my @result = callsame;
#             @result[0], @result[1], Supply.from-list(@result[2])
#         });
#     });
#     $r does WebAppWill;
#     $r.set_interface('direct');
# }
#
# multi sub trait_mod:<responds-as>(Routine:D $r, :$legacy-deferred!) is export {
# }
#
# multi sub trait_mod:<responds-as>(Routine:D $r, :$legacy-stream!) is export {
# }
#
#
# multi sub trait_mod:<responds-as>(Routine:D $r, :$promise!) is export {
#     $r.wrap(sub (%env) {
#         callsame.then: -> $p {
#             my @result = $p.result;
#             @result[0], @result[1], Supply.from-list(@result[2])
#         };
#     });
#     $r does WebAppWill;
#     $r.set_interface('promise');
# }
#
# multi sub trait_mod:<responds-as>(Routine:D $r, :$stream-channel!) is export {
#     $r.wrap(sub (%env) {
#         callsame.then: -> $p {
#             my @result = $p.result;
#             @result[0], @result[1], Supply.from-list(@result[2].list)
#         };
#     });
#     $r does WebAppWill;
#     $r.set_interface('stream-channel');
# }
#
# multi sub trait_mod:<respond-as>(Routine:D $r, :$stream-supply!) is export {
#     $r does WebAppWill;
#     $r.set_interface('stream-supply');
# }
#
# sub adapt-webapp(&app) is export {
    # return if &app ~~ WebAppWill or &app ~~ WebAppMay;
    # &app may-respond-as direct;
    # &app may-respond-as legacy-deferred;
    # &app may-respond-as legacy-stream;
    # &app may-respond-as promise;
    # &app may-respond-as stream-channel;
    # &app may-respond-as stream-supply;
    # Mu;
# }
