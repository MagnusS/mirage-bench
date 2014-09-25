open V1_LWT
open Printf
open Lwt

module Main (C: CONSOLE) (S: STACKV4) = struct

  module I = Init

  let start c s =
    I.start ();
    Tcpv4.Pcb.set_mode `Fast_start_proxy;

    (* listen on all ports *)
    S.listen_tcpv4 s (-1) (fun _ -> return_unit);
    S.listen s

end
