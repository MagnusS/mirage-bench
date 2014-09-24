open V1_LWT
open Printf
open Lwt

module Main (C: CONSOLE) (S: STACKV4) = struct

  module I = Init.Make(C)

  let start c s =
    Tcpv4.Pcb.set_mode `Fast_start_proxy;
    I.start c >>= fun () ->

    (* listen on all ports *)
    S.listen_tcpv4 s (-1) (fun _ -> return_unit);
    S.listen s

end
